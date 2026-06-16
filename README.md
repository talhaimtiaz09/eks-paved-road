# eks-paved-road

Production-grade EKS paved road built with Terraform, GitOps, Karpenter, security gates, and observability.

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
- Configure an AWS Budget alert at `$30/month` before provisioning resources.
- Use one AWS region consistently. Default target: `us-east-1`.
- Never commit AWS credentials, kubeconfigs, Terraform state, secrets, or generated plan files.
- Confirm teardown removes NAT gateways, Elastic IPs, EBS volumes, load balancers, and snapshots.

## Repository Layout

```text
.
├── .github/workflows/      # CI security and validation gates
├── docs/
│   ├── diagrams/           # Architecture diagrams and exported images
│   └── runbooks/           # Incident and disaster recovery runbooks
├── gitops/                 # ArgoCD applications and Kubernetes manifests
├── terraform/
│   ├── envs/dev/           # Deployable dev environment root module
│   └── modules/            # Reusable Terraform modules
└── CHECKLIST.md            # Optimized implementation checklist
```

## Current Status

Project scaffold created. Implementation starts with Milestone 0 safety rails, then the Terraform EKS MVP.

