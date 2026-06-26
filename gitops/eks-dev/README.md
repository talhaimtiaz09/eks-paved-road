# gitops/eks-dev/ — dev environment overlay (references the GitOps repo)

The ArgoCD/GitOps manifests live in the reusable GitOps repo and are **referenced,
not copied**:

> https://github.com/talhaimtiaz09/argocd-gitops-config — EKS entry: `eks/apps/root-app.yaml`
> (app-of-apps) + `project/eks-project.yaml` (AppProject).

This directory is a thin Kustomize overlay that points at that repo's bases and
injects the **3 env-specific, non-secret placeholders** the GitOps repo's
`eks/README.md` documents. Nothing is duplicated.

```
gitops/eks-dev/
├── root-app.yaml          # app-of-apps -> this repo's apps/ (replaces the GitOps repo's self-referential root)
├── project/
│   └── kustomization.yaml # references eks-project AppProject + adds this repo to sourceRepos
├── apps/
│   └── kustomization.yaml # references the 3 child Applications; injects role ARN + repoints secrets app
└── secrets/
    └── kustomization.yaml # references eks/secrets; injects region + secret name
```

## Why a local root instead of the GitOps repo's `eks/apps/root-app.yaml`

That root is self-referential: it pulls its children straight from the GitOps repo
with the placeholders unresolved. Kustomize can't patch a remote `Application` and
have ArgoCD re-pull the patched version through it. So `root-app.yaml` here is the
environment's app-of-apps — it points at `apps/`, which references the same three
children and patches them. The sync waves and behaviour are otherwise identical.

## The 3 placeholders

| Placeholder | Value (dev) | Injected in |
|---|---|---|
| `REPLACE_ME_AWS_REGION` | `us-east-1` | `secrets/kustomization.yaml` (static) |
| `REPLACE_ME_SECRET_NAME` | `eks-paved-road/dev/web-db-credentials` | `secrets/kustomization.yaml` (static) |
| `REPLACE_ME_ESO_IRSA_ROLE_ARN` | Terraform `eso_irsa_role_arn` output | `apps/kustomization.yaml` (sed by `bootstrap/install.sh`) |

The two static values are committed. The role ARN is filled at bootstrap from the
Terraform output and pushed (it is environment-specific but **not** a secret). The
actual DB credential never appears here — it stays in AWS Secrets Manager and is
materialised into the cluster by the ExternalSecret via IRSA.

## Apply

Handled by `bootstrap/install.sh`. Manually it is:

```bash
kubectl apply -k gitops/eks-dev/project       # AppProject (this repo allowed)
kubectl apply -f gitops/eks-dev/root-app.yaml  # app-of-apps
```
