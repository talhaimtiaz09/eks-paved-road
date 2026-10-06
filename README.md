# eks-paved-road

Production-grade EKS paved road built with Terraform, GitOps, Karpenter, security gates, and observability.

**Project page:** https://talhaimtiaz09.github.io/eks-paved-road/

![Architecture: Terraform builds a VPC with one NAT gateway and an EKS cluster with an OIDC provider. Argo CD syncs from Git; the External Secrets Operator assumes an IAM role through IRSA, reads one secret from AWS Secrets Manager and hands it to the web pods. No static AWS keys, no LoadBalancer.](docs/images/eks-architecture.png)

## Goal

Build a reproducible AWS EKS platform that an application team could use safely:

- Terraform provisions the network, EKS cluster, node capacity, IAM, and platform add-ons.
- GitOps delivers applications and platform configuration through ArgoCD.
- IRSA and External Secrets remove static cloud keys and plaintext secrets from workloads.
- Prometheus, Grafana, Loki, and alerting make the platform observable.
- Karpenter proves autoscaling, consolidation, and FinOps discipline.
- GitHub Actions blocks unsafe infrastructure and vulnerable images.

## Build Order

1. Finish the MVP cluster lifecycle before adding GitOps or platform add-ons.
2. Commit at the end of every milestone with a short README note describing what works.
3. Record a short demo clip for every demo checkpoint.
4. Destroy all cloud resources at the end of every work session.

## Safety Rules

- Use a dedicated AWS account or isolated least-privilege project IAM user.
- Enable root MFA and use a non-root admin identity for daily work.
- Configure an AWS Budget alert at `$5/month` before provisioning resources.
- Use one AWS region consistently. Default target: `us-east-1`.
- Never commit AWS credentials, kubeconfigs, Terraform state, secrets, or generated plan files.
- Confirm teardown removes NAT gateways, Elastic IPs, EBS volumes, load balancers, and snapshots.

## Repository Layout

```text
.
├── .github/workflows/      # CI security and validation gates (Phase 4)
├── bootstrap/              # Thin post-apply step: install Argo CD, hand over to GitOps
├── docs/
│   ├── index.html          # Project page
│   ├── images/             # Diagrams used by the page and this README
│   ├── diagrams/           # Architecture diagrams and exported images
│   └── runbooks/           # Incident and disaster recovery runbooks
├── gitops/eks-dev/         # Kustomize overlay that REFERENCES the GitOps repo + injects env values
├── prompts/                # Image-generation prompts for the diagrams
├── terraform/
│   ├── envs/dev/           # Deployable dev environment root module
│   └── modules/
│       ├── vpc/            # VPC: public + private subnets, ONE NAT gateway
│       ├── eks/            # Wraps terraform-aws-modules/eks/aws; OIDC; spot t3.small node group
│       └── irsa/           # Least-privilege IAM role for the ESO ServiceAccount
└── CHECKLIST.md            # Optimized implementation checklist
```

## GitOps lives in a separate, reusable repo

The ArgoCD applications and Kubernetes manifests are **not** in this repo — they are
**referenced, not copied** from:

> **https://github.com/talhaimtiaz09/argocd-gitops-config**
> EKS entry: `eks/apps/root-app.yaml` (app-of-apps) + `project/eks-project.yaml`.
> It installs the External Secrets Operator (IRSA), wires AWS Secrets Manager, and
> deploys the sample `web` app. Argo CD itself is installed from that repo's pinned
> `bootstrap/argocd-values.yaml`.

This repo holds the Terraform that builds the cluster and a thin Kustomize overlay
(`gitops/eks-dev/`) that references the GitOps bases and injects three env-specific,
non-secret placeholders (ESO IRSA role ARN, region, secret name). See
`gitops/eks-dev/README.md` and `bootstrap/README.md`.

## Terraform

- `terraform/modules/vpc` — VPC with public + private subnets across 2 AZs and
  exactly **one** NAT gateway (cost rule). Wraps `terraform-aws-modules/vpc/aws`.
- `terraform/modules/eks` — wraps `terraform-aws-modules/eks/aws` (v20), enables the
  **OIDC provider** for IRSA, and runs one **spot `t3.small`** managed node group.
- `terraform/modules/irsa` — least-privilege IAM role for the ESO ServiceAccount:
  `secretsmanager:GetSecretValue` + `DescribeSecret` on the **one** app secret,
  trust bound to the cluster OIDC provider. No static keys.
- `terraform/envs/dev` — deployable root. Also creates the Secrets Manager secret
  **container** `eks-paved-road/dev/web-db-credentials`; the **value is set
  out-of-band**, never in Git or state.

Region is **`us-east-1`** throughout. Providers are pinned (`aws ~> 5.70`); module
versions are pinned (`vpc ~> 5.13`, `eks ~> 20.24`).

Outputs: `cluster_name`, `region`, `kubeconfig_command`, `oidc_provider_arn`,
`eso_irsa_role_arn`, `db_secret_name` (+ VPC/subnet ids).

### Cluster-less validation (fmt/validate only)

```bash
cd terraform/envs/dev
terraform fmt -recursive ../..
terraform init -backend=false
terraform validate
```

## State backend (S3 + DynamoDB)

Remote state lives in an **S3 bucket** (versioned, encrypted, public access blocked)
with a **DynamoDB lock table**. These are created once by a separate backend
bootstrap and left running permanently — the only always-on stack (pennies). Supply
them at init time with a partial backend config (see `terraform/envs/dev/backend.tf`):

```bash
terraform init \
  -backend-config="bucket=<your-state-bucket>" \
  -backend-config="key=eks-paved-road/dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=<your-lock-table>" \
  -backend-config="encrypt=true"
```

## Why port-forward only (no LoadBalancer)

All UI access (Argo CD, later Grafana) is via `kubectl port-forward`. A
`type: LoadBalancer` Service provisions an AWS ELB that bills hourly and lingers
after teardown — a classic orphaned-cost trap. Port-forwarding is free, needs no
public exposure, and disappears the instant you stop it:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

## Deploy / teardown

```bash
# 1. apply infra
cd terraform/envs/dev && terraform apply
# 2. set the secret value out-of-band (never in Git/state)
aws secretsmanager put-secret-value \
  --secret-id eks-paved-road/dev/web-db-credentials \
  --secret-string '{"username":"webuser","password":"<choose>"}'
# 3. point kubectl at the cluster, then bootstrap GitOps
aws eks update-kubeconfig --region us-east-1 --name eks-paved-road-dev
../../bootstrap/install.sh
# ... at session end:
terraform destroy   # then sweep AWS console for orphans (NAT, EIP, EBS, ELB, ENI)
```

## Current Status

Phase 2 in progress: Terraform (VPC + EKS + IRSA + Secrets Manager container) and the
thin GitOps bootstrap are scaffolded and validated (fmt/validate only — no cluster
applied yet).

