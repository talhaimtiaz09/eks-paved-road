# Architecture

## Bird's-eye view

`eks-paved-road` is a reproducible AWS EKS platform split across **two repos with one
clean seam**:

- **This repo (`eks-paved-road`)** — the *infrastructure*. Terraform builds the
  network, the EKS cluster, the IAM trust (IRSA), and the Secrets Manager secret
  *container*. A thin bootstrap installs Argo CD and hands the cluster to GitOps.
- **The GitOps repo (`argocd-gitops-config`)** — the *desired state*. Argo CD
  Applications, the External Secrets wiring, and the sample `web` workload. This
  repo **references** those manifests, it never copies them.

The seam between them is **three non-secret, environment-specific values** that
Terraform produces and a small Kustomize overlay here injects into the referenced
GitOps manifests: the **ESO IRSA role ARN**, the **AWS region**, and the **Secrets
Manager secret name**.

The end-to-end story in one breath:

> Terraform stands up a VPC (one NAT) and an EKS cluster with an **OIDC provider**.
> That OIDC provider lets the **External Secrets Operator** assume a **least-privilege
> IAM role (IRSA)** — no static AWS keys anywhere. ESO reads a secret from **AWS
> Secrets Manager** and materializes it as a Kubernetes Secret, which the **web** pod
> consumes. **Argo CD** drives all of it declaratively from Git and self-heals. Every
> UI is reached by **port-forward** (never a LoadBalancer), and the whole cluster is
> `terraform destroy`-ed at the end of each session.

```
                    ┌─────────────────────────── AWS (us-east-1) ───────────────────────────┐
                    │                                                                        │
   terraform apply  │   ┌── VPC 10.0.0.0/16 ──────────────────────────────────────────┐     │
  ────────────────► │   │  public subnets ─► IGW                                       │     │
                    │   │  private subnets ─► ONE NAT gateway ─► egress                │     │
                    │   │       │                                                       │     │
                    │   │       ▼  EKS managed node group (spot t3.small ×1–2)          │     │
                    │   │   ┌──────────────── EKS cluster: eks-paved-road-dev ───────┐  │     │
                    │   │   │  control plane + OIDC provider ──────────────┐         │  │     │
                    │   │   │                                              │ trusts  │  │     │
                    │   │   │  ns: argocd            ns: external-secrets  ▼         │  │     │
                    │   │   │   Argo CD  ──drives──►  ESO  ◄─IRSA role── (assume via  │  │     │
                    │   │   │     │                    │    OIDC, no keys) OIDC)      │  │     │
                    │   │   │     │ syncs              │ GetSecretValue              │  │     │
                    │   │   │     ▼                    ▼                              │  │     │
                    │   │   │   ns: web         AWS Secrets Manager ◄────────────────┼──┼─────┤
                    │   │   │   web pod ◄─env── K8s Secret  eks-paved-road/dev/       │  │  GetSecretValue
                    │   │   │  (nginx)          web-db-credentials  web-db-credentials│  │     │
                    │   │   └────────────────────────────────────────────────────────┘  │     │
                    │   └──────────────────────────────────────────────────────────────┘     │
                    │   IAM OIDC provider · IRSA role · Secrets Manager secret · S3+DynamoDB   │
                    └────────────────────────────────────────────────────────────────────────┘
            ▲                                          ▲
            │ git pull (desired state)                 │ git pull (referenced bases + patches)
   ┌────────┴───────────────┐              ┌───────────┴──────────────────────┐
   │ argocd-gitops-config   │  referenced  │ eks-paved-road / gitops/eks-dev   │
   │ eks/apps, eks/secrets, │ ◄─────────── │ overlay: injects the 3 values     │
   │ overlays/eks, project  │   (not copied)│ root-app.yaml = app-of-apps       │
   └────────────────────────┘              └───────────────────────────────────┘
```

---

## Layer 1 — Terraform (this repo)

Root module: `terraform/envs/dev`. It wires three local modules plus the Secrets
Manager secret, and exposes the outputs the GitOps layer needs. Providers are pinned
(`aws ~> 5.70`); module versions are pinned. Region is `us-east-1` throughout.

```
terraform/envs/dev  (root)
  ├─ module.vpc      → terraform/modules/vpc   (wraps terraform-aws-modules/vpc/aws ~> 5.13)
  ├─ module.eks      → terraform/modules/eks   (wraps terraform-aws-modules/eks/aws ~> 20.24)
  ├─ aws_secretsmanager_secret.web_db          (container only — no value)
  └─ module.irsa     → terraform/modules/irsa  (IAM role for the ESO ServiceAccount)
```

### State backend — `backend.tf`

Remote state in **S3** (versioned, encrypted, public-access-blocked) with a
**DynamoDB** lock table. This is the *only* stack left running permanently (pennies);
the cluster itself is destroyed each session. The bucket/table are created once by a
separate backend bootstrap and supplied at `init` time via partial backend config, so
nothing account-specific is committed. For cluster-less work: `terraform init -backend=false`.

### `module.vpc` — the network

Wraps the official VPC module. Purpose: give the cluster a private place to run nodes
with controlled egress, at minimum cost.

- **CIDR `10.0.0.0/16`**, spread across **2 Availability Zones** (EKS requires ≥2).
- **Public subnets** (`/24` per AZ) → route to an **Internet Gateway**. Host the NAT.
- **Private subnets** (`/24` per AZ) → route to **exactly one NAT gateway**
  (`single_nat_gateway = true`). The **nodes live here**; the single NAT is the
  deliberate cost trade-off (one NAT instead of one-per-AZ).
- **Subnet tags** (`kubernetes.io/role/elb`, `…/internal-elb`,
  `kubernetes.io/cluster/<name>=shared`) are the conventional EKS discovery tags.

**Connects to:** `module.eks` consumes `private_subnet_ids` for the node group and
`vpc_id` for the cluster.

### `module.eks` — the cluster

Wraps `terraform-aws-modules/eks/aws` v20. Purpose: a Kubernetes control plane plus a
small, cheap, self-managed-by-EKS pool of nodes — and, critically, the **OIDC provider**
that makes keyless IAM possible.

- **Control plane** at Kubernetes `1.31`. **Public API endpoint** so `kubectl` /
  `argocd` port-forward works from a workstation; **nodes stay private**.
- **`enable_irsa = true`** → EKS creates an **IAM OIDC identity provider** for the
  cluster's issuer. This is the linchpin of the security model (see Layer 3).
- **One spot `t3.small` managed node group** (`min 1 / desired 1 / max 2`,
  `capacity_type = SPOT`) in the private subnets — the cost rule.
- **Access via EKS access entries** (`authentication_mode = API_AND_CONFIG_MAP`,
  `enable_cluster_creator_admin_permissions = true`, plus optional
  `cluster_admin_arns`). No `aws-auth` ConfigMap juggling, so **no Kubernetes provider
  is needed** in Terraform — keeps the apply self-contained.

**Connects to:** exposes `oidc_provider_arn` and `oidc_provider_url` to `module.irsa`,
and `cluster_name` to the kubeconfig/outputs.

### `aws_secretsmanager_secret.web_db` — the secret container

Defined directly in the root (`main.tf`). Purpose: hold the web app's DB credentials
**outside** Git and Terraform state.

- Name: **`eks-paved-road/dev/web-db-credentials`**, JSON-shaped
  `{"username":…,"password":…}`.
- Terraform creates **only the container** — there is **no
  `aws_secretsmanager_secret_version`**, so the credential value never touches Git or
  state. The value is set out-of-band (`aws secretsmanager put-secret-value …`).
- `recovery_window_in_days = 0` so teardown leaves nothing lingering between sessions.

**Connects to:** its `.arn` is passed to `module.irsa` (least-privilege scope), and its
`.name` is surfaced as the `db_secret_name` output (injected into the GitOps overlay).

### `module.irsa` — keyless IAM for External Secrets

Purpose: let exactly one Kubernetes ServiceAccount — ESO's controller — read exactly
one secret, with **no static AWS keys**.

- **Trust policy** (`sts:AssumeRoleWithWebIdentity`): federated to the cluster's OIDC
  provider, conditioned on
  `…:sub = system:serviceaccount:external-secrets:external-secrets` and
  `…:aud = sts.amazonaws.com`. Only the ESO controller pod's projected token can
  assume this role.
- **Permission policy** (least privilege): `secretsmanager:GetSecretValue` +
  `DescribeSecret` on the **one** secret ARN only. Nothing else in Secrets Manager is
  readable.
- Role name: `eks-paved-road-dev-eso-irsa`.

**Connects to:** trusts `module.eks`'s OIDC provider; scoped to
`aws_secretsmanager_secret.web_db.arn`; its `role_arn` becomes the `eso_irsa_role_arn`
output.

### Outputs — the contract to the GitOps layer

| Output | Used for |
|---|---|
| `cluster_name`, `region`, `kubeconfig_command` | `aws eks update-kubeconfig` / operator ergonomics |
| `oidc_provider_arn` | proof/visibility of the IRSA trust anchor |
| **`eso_irsa_role_arn`** | injected as `REPLACE_ME_ESO_IRSA_ROLE_ARN` |
| **`db_secret_name`** | injected as `REPLACE_ME_SECRET_NAME` |
| `vpc_id`, `private_subnet_ids` | inspection |

---

## Layer 2 — Bootstrap (this repo, `bootstrap/`)

The **single manual step** after `terraform apply`. Everything past it is GitOps.
`bootstrap/install.sh`:

1. **Injects** the ESO IRSA role ARN from `terraform output eso_irsa_role_arn` into
   `gitops/eks-dev/apps/kustomization.yaml` (the only post-apply value; region and
   secret name are static and already committed). The ARN is **not** a secret.
2. **Installs Argo CD** via Helm — pinned chart **`7.7.11`** (→ Argo CD v2.13.x),
   **reusing** the GitOps repo's `bootstrap/argocd-values.yaml` (fetched at runtime,
   not copied). `server.insecure` is on; access is **port-forward only**.
3. **Applies** the AppProject overlay and the dev app-of-apps (`root-app.yaml`).

After this, Argo CD owns reconciliation; the script never runs again unless you
re-bootstrap.

---

## Layer 3 — GitOps (referenced repo + local overlay)

### The referenced repo

`https://github.com/talhaimtiaz09/argocd-gitops-config` holds the actual manifests:

- `project/eks-project.yaml` — the Argo CD **AppProject** (allow-list of repos,
  destinations, resource kinds).
- `eks/apps/{external-secrets-operator,secrets,web}.yaml` — three child Argo CD
  **Applications**, ordered by **sync-waves**.
- `eks/secrets/{aws-secret-store,web-db-external-secret}.yaml` — the **ESO SecretStore**
  (AWS provider, IRSA auth) and the **ExternalSecret** (reference only).
- `overlays/eks` + `base` — the sample **web** workload (nginx) that consumes the
  synced secret via `envFrom`.

These contain **three placeholders** by design (all non-secret, env-specific):
`REPLACE_ME_ESO_IRSA_ROLE_ARN`, `REPLACE_ME_AWS_REGION`, `REPLACE_ME_SECRET_NAME`.

### The local overlay — `gitops/eks-dev/`

A thin Kustomize overlay that **references** the bases above and patches in the three
values. Nothing is duplicated.

```
gitops/eks-dev/
  ├─ root-app.yaml         app-of-apps → this repo's apps/  (the env entrypoint)
  ├─ project/              references eks-project + adds THIS repo to sourceRepos
  ├─ apps/                 references the 3 child Applications; patches:
  │                          • ESO role ARN (helm param)         [sed at bootstrap]
  │                          • repoint eks-secrets → this repo's secrets/ overlay
  └─ secrets/              references eks/secrets; patches region + secret name [static]
```

Why a local `root-app.yaml` instead of the GitOps repo's `eks/apps/root-app.yaml`?
That upstream root is **self-referential** — it re-pulls its children straight from the
GitOps repo with placeholders unresolved, and Kustomize can't patch a remote
`Application` and have Argo CD re-pull the patched version *through* it. So this repo's
`root-app.yaml` is the environment's app-of-apps; it points at `apps/`, which
references the same three children and patches them. Sync waves and behavior are
otherwise identical.

> **Tooling note:** single remote files are referenced via `raw.githubusercontent.com`
> URLs; the git `//path?ref=` form only works for *directories* containing a
> `kustomization.yaml` (which `eks/secrets` has, but `eks/apps/*` and `project/` do not).

### The placeholder seam (how the two repos meet)

| Placeholder | Lives in (GitOps repo) | Resolved by (this repo) | Source |
|---|---|---|---|
| `REPLACE_ME_AWS_REGION` | `eks/secrets/aws-secret-store.yaml` | `secrets/` kustomize patch | static `us-east-1` |
| `REPLACE_ME_SECRET_NAME` | `eks/secrets/web-db-external-secret.yaml` | `secrets/` kustomize patch | static secret name |
| `REPLACE_ME_ESO_IRSA_ROLE_ARN` | `eks/apps/external-secrets-operator.yaml` | `apps/` kustomize patch | `terraform output` (sed) |

The two static values are committed; the role ARN is filled at bootstrap and pushed
(environment-specific but **not** secret). The **actual DB credential never appears in
either repo** — it stays in AWS Secrets Manager and is materialized into the cluster at
runtime by ESO via IRSA.

---

## How a sync actually flows (sync waves)

Argo CD applies the app-of-apps children in wave order so dependencies exist before
their consumers:

1. **Wave 1 — `eks-external-secrets`**: installs the External Secrets Operator (Helm
   chart `0.10.4`, CRDs + controller) into `ns: external-secrets`. Its ServiceAccount
   is annotated `eks.amazonaws.com/role-arn = <ESO IRSA role>`. Because of that
   annotation + the OIDC trust, the controller pod gets temporary AWS creds with **no
   static keys**.
2. **Wave 2 — `eks-secrets`**: applies, into `ns: web`, the **SecretStore**
   (`provider: aws`, `region`, `auth: {}` → uses the SA's IRSA creds) and the
   **ExternalSecret** (points at `eks-paved-road/dev/web-db-credentials`). ESO calls
   `secretsmanager:GetSecretValue`, then **creates/owns a Kubernetes Secret**
   `web-db-credentials` with `username`/`password` keys.
3. **Wave 3 — `eks-web`**: deploys the **web** workload (nginx, 2 replicas) from
   `overlays/eks`, which `envFrom`-mounts the `web-db-credentials` Secret. The pod
   sees the DB creds as env vars — and contains **zero** AWS keys.

`refreshInterval: 1h` on the ExternalSecret means rotating the value in Secrets Manager
propagates into the cluster automatically. `selfHeal + prune` on every Application means
deleting or drifting any synced resource is reverted to Git's desired state.

---

## Cross-cutting concerns

### Security model — no static keys, least privilege

```
ESO pod ──projected SA token──► AWS STS ──AssumeRoleWithWebIdentity──► eso-irsa role
   ▲                                  (trust: OIDC provider + sub + aud)      │
   │ annotated SA: eks.amazonaws.com/role-arn                                 │ GetSecretValue
   └──────────────────────────── temporary creds ◄───────────────────────────┘ (one secret only)
```

- **IRSA, not node IAM**: the secret-reading permission is bound to the ESO
  ServiceAccount, not to the node role — so no other pod inherits it.
- **Least privilege**: the role can `GetSecretValue`/`DescribeSecret` on **one** ARN.
- **No secret in Git/state**: Terraform makes only the container; the value is
  out-of-band; Git holds only an ExternalSecret *reference*.
- **No public workload exposure**: see below.

### Cost model

| Lever | Choice | Why |
|---|---|---|
| NAT gateways | **one** (`single_nat_gateway`) | NAT is a top hourly cost; one suffices for dev |
| Nodes | **spot `t3.small`** ×1–2 | cheapest viable EKS workers |
| UI access | **port-forward only** | a `type: LoadBalancer` provisions a billed ELB that lingers after teardown |
| Database | in-cluster pod (not RDS) | avoid managed-DB cost |
| Lifecycle | `terraform destroy` each session | control plane (~$0.10/hr) isn't free-tier |
| Persistent footprint | S3 + DynamoDB backend only | pennies; everything else is ephemeral |

### Why port-forward, never LoadBalancer

All UIs (Argo CD now, Grafana later) are reached with
`kubectl -n argocd port-forward svc/argocd-server 8080:443`. It's free, needs no public
exposure, and vanishes the instant you stop it — avoiding the classic orphaned-ELB cost
trap. Argo CD runs with `server.insecure` so plaintext port-forward works.

---

## Lifecycle summary

```
terraform apply                       # VPC, EKS+OIDC, IRSA, secret container
aws secretsmanager put-secret-value   # set the value OUT-OF-BAND (never in Git/state)
aws eks update-kubeconfig             # point kubectl at the cluster
bootstrap/install.sh                  # install Argo CD → hand over to GitOps
#   Argo CD: ESO (wave 1) → SecretStore/ExternalSecret (wave 2) → web (wave 3)
terraform destroy                     # at session end, then sweep for orphans
```

See `README.md` for commands, `bootstrap/README.md` for the bootstrap detail, and
`gitops/eks-dev/README.md` for the overlay.
