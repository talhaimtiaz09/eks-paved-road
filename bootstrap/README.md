# bootstrap/ — the one manual step after `terraform apply`

`install.sh` installs Argo CD and hands the cluster to GitOps. Everything after it
is declarative and self-healing.

## What it does

1. **Injects** the ESO IRSA role ARN (`terraform output eso_irsa_role_arn`) into
   `gitops/eks-dev/apps/kustomization.yaml`. Region and secret name are already
   committed (static, non-secret). The role ARN is the only post-apply value.
2. **Installs Argo CD** via Helm — pinned chart `7.7.11`, reusing the GitOps repo's
   `bootstrap/argocd-values.yaml` (fetched at runtime, not copied). `server.insecure`
   is on; access is **port-forward only**, never a LoadBalancer.
3. **Applies** the `eks-project` AppProject (with this repo added to its
   `sourceRepos`) and the dev app-of-apps `root-app.yaml`.

Argo CD then syncs, in wave order:
`external-secrets` (1) → `SecretStore` + `ExternalSecret` (2) → `web` (3).

## Prerequisites

- `terraform apply` has completed in `terraform/envs/dev`.
- `kubectl` points at the cluster: `aws eks update-kubeconfig --region us-east-1 --name eks-paved-road-dev`.
- The Secrets Manager value is set out-of-band:
  ```bash
  aws secretsmanager put-secret-value \
    --secret-id eks-paved-road/dev/web-db-credentials \
    --secret-string '{"username":"webuser","password":"<choose>"}'
  ```
- `helm`, `kubectl`, `terraform`, and `curl` are installed.

## Run

```bash
./bootstrap/install.sh
```

Because Argo CD pulls manifests from GitHub, **commit and push** the injected role
ARN (step 1 prints the reminder) so the cluster syncs the real value.

## Placeholder injection — how the 3 values are wired

| Placeholder | Lives in (GitOps repo) | Resolved by (this repo) |
|---|---|---|
| `REPLACE_ME_AWS_REGION` | `eks/secrets/aws-secret-store.yaml` | `gitops/eks-dev/secrets` kustomize patch (static) |
| `REPLACE_ME_SECRET_NAME` | `eks/secrets/web-db-external-secret.yaml` | `gitops/eks-dev/secrets` kustomize patch (static) |
| `REPLACE_ME_ESO_IRSA_ROLE_ARN` | `eks/apps/external-secrets-operator.yaml` | `gitops/eks-dev/apps` kustomize patch (sed from Terraform output) |

The overlays **reference** the GitOps repo via kustomize remote bases and patch the
values — no manifests are copied. See `gitops/eks-dev/` for the overlay and
`../README.md` for the full architecture.
