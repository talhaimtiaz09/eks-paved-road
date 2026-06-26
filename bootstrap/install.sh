#!/usr/bin/env bash
# Thin bootstrap: install Argo CD, then hand the cluster over to GitOps.
#
# This is the ONLY manual step after `terraform apply`. Everything past it is
# GitOps: Argo CD syncs the dev EKS app-of-apps (ESO -> AWS Secrets Manager wiring
# -> sample web app) from this repo's gitops/eks-dev overlay, which references the
# reusable GitOps repo and injects the 3 env-specific placeholders.
#
# Reuses the GitOps repo's pinned Argo CD chart + values (fetched at runtime, not
# copied here). Run it from a shell that already has kubectl pointed at the cluster
# (terraform output kubeconfig_command) and terraform available in terraform/envs/dev.
#
# UI access is port-forward ONLY — we never create a LoadBalancer (cost rule).
set -euo pipefail

# --- pins (never 'latest') -------------------------------------------------
ARGOCD_CHART_VERSION="7.7.11" # argo/argo-cd 7.7.11 -> Argo CD v2.13.x
GITOPS_REPO_RAW="https://raw.githubusercontent.com/talhaimtiaz09/argocd-gitops-config/main"
ARGOCD_VALUES_URL="${GITOPS_REPO_RAW}/bootstrap/argocd-values.yaml"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/envs/dev"
APPS_KUSTOMIZATION="${REPO_ROOT}/gitops/eks-dev/apps/kustomization.yaml"

# --- 1. inject the ESO IRSA role ARN from Terraform output ------------------
# region + secret name are static and already committed in the overlays; only the
# role ARN is known after apply. It is NOT a secret.
echo ">> Reading ESO IRSA role ARN from Terraform output..."
ESO_ROLE_ARN="$(terraform -chdir="${TF_DIR}" output -raw eso_irsa_role_arn)"
echo "   ${ESO_ROLE_ARN}"

if grep -q "REPLACE_ME_ESO_IRSA_ROLE_ARN" "${APPS_KUSTOMIZATION}"; then
  echo ">> Injecting role ARN into gitops/eks-dev/apps/kustomization.yaml"
  sed -i "s#REPLACE_ME_ESO_IRSA_ROLE_ARN#${ESO_ROLE_ARN}#g" "${APPS_KUSTOMIZATION}"
  echo "   NOTE: commit + push this change so Argo CD (which pulls from GitHub) sees it:"
  echo "         git add gitops/eks-dev/apps/kustomization.yaml && git commit && git push"
else
  echo ">> Role ARN already injected (no sentinel found) — skipping."
fi

# --- 2. install Argo CD (pinned chart, reused values) -----------------------
echo ">> Installing Argo CD ${ARGOCD_CHART_VERSION} (port-forward only, server.insecure)..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo

curl -fsSL -o /tmp/argocd-values.yaml "${ARGOCD_VALUES_URL}"
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version "${ARGOCD_CHART_VERSION}" \
  --values /tmp/argocd-values.yaml \
  --wait
kubectl -n argocd rollout status deploy/argocd-server

# --- 3. hand over to GitOps -------------------------------------------------
# AppProject (eks-project + this repo added to sourceRepos), then the app-of-apps.
echo ">> Applying AppProject and dev app-of-apps..."
kubectl apply -k "${REPO_ROOT}/gitops/eks-dev/project"
kubectl apply -f "${REPO_ROOT}/gitops/eks-dev/root-app.yaml"

# --- done -------------------------------------------------------------------
cat <<'EOF'

Argo CD installed and the dev app-of-apps applied. Access the UI via port-forward:

  kubectl -n argocd port-forward svc/argocd-server 8080:443   # keep running
  # admin password:
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d; echo

Sync order: external-secrets (wave 1) -> SecretStore/ExternalSecret (wave 2) -> web (wave 3).
EOF
