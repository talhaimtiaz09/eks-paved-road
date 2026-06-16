# eks-paved-road Implementation Checklist

Use this as the source of truth for execution. Do not start a later milestone until the current milestone has been committed, documented, demoed where required, and torn down cleanly.

## Global Definition of Done

- [ ] All changes are committed to Git with a meaningful commit message.
- [ ] README contains a one-paragraph note for the completed milestone.
- [ ] Any required demo clip or screenshot is saved under `docs/`.
- [ ] `terraform destroy` has completed successfully for session-ending work.
- [ ] AWS console has been checked for orphaned cost items: NAT gateways, Elastic IPs, EBS volumes, RDS snapshots, load balancers, and unattached ENIs.
- [ ] No plaintext secrets, kubeconfigs, Terraform state files, or generated plans are committed.

## Milestone 0 - Foundations And Safety Rails

### Account And Cost Controls

- [ ] Use a dedicated AWS account or isolated project IAM user.
- [ ] Enable MFA on the AWS root account.
- [ ] Create a non-root IAM admin identity for daily project work.
- [ ] Configure an AWS Budget alert at `$30/month` to `talha.imtiaz.dev@gmail.com`.
- [ ] Pick one region and document it. Recommended: `us-east-1`.
- [ ] Define a project tag set: `Project=eks-paved-road`, `Owner=talhaimtiaz09`, `Environment=dev`, `ManagedBy=terraform`.

### Local Toolchain

- [ ] Install and verify `terraform`.
- [ ] Install and verify `aws`.
- [ ] Install and verify `kubectl`.
- [ ] Install and verify `helm`.
- [ ] Install `eksctl` for inspection only.
- [ ] Optionally install `k9s` for demos.
- [ ] Configure a named AWS profile.
- [ ] Verify identity with `aws sts get-caller-identity --profile <profile>`.

### Repo Bootstrap

- [ ] Keep this repository private until the first safe public-ready pass.
- [ ] Confirm `.gitignore` excludes state, credentials, kubeconfigs, logs, and build artifacts.
- [ ] Add the first architecture sketch under `docs/diagrams/`.
- [ ] Commit the scaffold.

### Acceptance Criteria

- [ ] A clean clone shows the intended layout and safety rules.
- [ ] Local Git commits use `talha.imtiaz.dev@gmail.com`.
- [ ] AWS budget and MFA are in place before infrastructure work begins.

## Milestone 1 - MVP Terraform EKS Lifecycle

### Backend Bootstrap

- [ ] Create a small Terraform backend bootstrap for S3 state and DynamoDB locking.
- [ ] Apply backend bootstrap once.
- [ ] Enable S3 bucket versioning and server-side encryption.
- [ ] Block public access on the state bucket.
- [ ] Document backend names and region in README.

### Terraform Structure

- [ ] Build `terraform/envs/dev` as the deployable root module.
- [ ] Build `terraform/modules/vpc` for VPC, subnets, route tables, NAT, and tags.
- [ ] Build `terraform/modules/eks` around the official `terraform-aws-modules/eks/aws` module.
- [ ] Configure providers with explicit versions.
- [ ] Add variables with clear descriptions and safe defaults.
- [ ] Add outputs for cluster name, region, kubeconfig command, and VPC identifiers.
- [ ] Run `terraform fmt -recursive`.
- [ ] Run `terraform validate`.

### EKS MVP

- [ ] Provision a VPC with public and private subnets.
- [ ] Use one NAT gateway for cost control.
- [ ] Provision an EKS cluster.
- [ ] Create a small managed node group, starting with two `t3.medium` or smaller nodes if supported by workload requirements.
- [ ] Configure cluster access for the deploying IAM identity.
- [ ] Update kubeconfig with `aws eks update-kubeconfig`.
- [ ] Verify `kubectl get nodes` returns Ready nodes.
- [ ] Deploy a trivial scheduling test pod.
- [ ] Remove the test pod after verification.

### Destructive Lifecycle Test

- [ ] Run `terraform destroy`.
- [ ] Confirm AWS has no orphaned cost resources.
- [ ] Run `terraform apply` from zero.
- [ ] Confirm cluster and nodes return to Ready.
- [ ] Destroy again at the end of the work session.

### Acceptance Criteria

- [ ] A documented command sequence can create and destroy the cluster from zero.
- [ ] No manual console changes are required except backend bootstrap if explicitly documented.
- [ ] Demo clip shows apply, node readiness, test pod scheduling, and destroy.

## Milestone 2 - GitOps Delivery With ArgoCD

- [ ] Install ArgoCD via Helm through Terraform or a documented bootstrap script.
- [ ] Keep ArgoCD UI access to port-forward for portfolio scope.
- [ ] Document why public ArgoCD exposure is avoided.
- [ ] Add `gitops/` structure for platform apps and sample app manifests.
- [ ] Create an ArgoCD `Application` that watches this repo or a dedicated GitOps path.
- [ ] Deploy a real sample app with an API and Postgres dependency.
- [ ] Push a manifest change and confirm ArgoCD auto-syncs it.
- [ ] Manually delete a synced resource and confirm ArgoCD self-heals it.
- [ ] Add a GitOps flow diagram to README.
- [ ] Record demo clip: Git push, ArgoCD sync, app update.

## Milestone 3 - Secrets And IRSA

- [ ] Enable the EKS OIDC provider through Terraform.
- [ ] Create IAM roles for service accounts using least privilege.
- [ ] Install External Secrets Operator.
- [ ] Store app database credentials in AWS Secrets Manager.
- [ ] Sync credentials into Kubernetes with `ExternalSecret`.
- [ ] Prove pods do not contain static AWS keys.
- [ ] Rotate the secret in Secrets Manager.
- [ ] Confirm the Kubernetes secret updates.
- [ ] Add a README security posture section covering IRSA, ESO, and static-key avoidance.

## Milestone 4 - Observability

- [ ] Install `kube-prometheus-stack`.
- [ ] Install Loki for log aggregation.
- [ ] Verify Grafana cluster dashboards: node CPU, node memory, pod health.
- [ ] Build or import an app-specific dashboard with request rate, latency, and error rate.
- [ ] Configure one meaningful alert, such as crash looping or high error rate.
- [ ] Trigger the alert intentionally.
- [ ] Save dashboard screenshots under `docs/`.
- [ ] Record demo clip showing dashboard behavior and alert firing.

## Milestone 5 - Karpenter Autoscaling And FinOps

- [ ] Install Karpenter with Terraform or GitOps.
- [ ] Configure IAM permissions for Karpenter.
- [ ] Create a NodePool supporting spot and on-demand capacity.
- [ ] Enable consolidation.
- [ ] Deploy a workload that requires additional capacity.
- [ ] Confirm Karpenter provisions nodes quickly.
- [ ] Remove the workload and confirm Karpenter consolidates/removes nodes.
- [ ] Record before/after node count and cost implication.
- [ ] Add an autoscaling and FinOps README section.
- [ ] Record demo clip of scale up and scale down.

## Milestone 6 - DevSecOps Supply Chain Gates

- [ ] Add GitHub Actions workflow for Terraform formatting and validation.
- [ ] Add Checkov or tfsec scanning for Terraform.
- [ ] Fail CI on critical infrastructure findings.
- [ ] Add Trivy image scanning for the sample app container.
- [ ] Fail CI on critical CVEs.
- [ ] Intentionally introduce a blocked finding in a short-lived branch.
- [ ] Capture failed CI evidence.
- [ ] Fix the issue and capture passing CI evidence.
- [ ] Document security gates in README.

## Milestone 7 - Incident And Disaster Recovery

- [ ] Write `docs/runbooks/disaster-recovery.md`.
- [ ] Write `docs/runbooks/app-alert-incident.md`.
- [ ] Destroy the full environment.
- [ ] Rebuild from scratch using only the runbook.
- [ ] Time the rebuild.
- [ ] Trigger the Milestone 4 alert.
- [ ] Follow the incident runbook to resolution.
- [ ] Record incident simulation demo clip.

## Milestone 8 - Hiring Package

- [ ] Finalize architecture diagram and place it near the top of README.
- [ ] README covers problem, platform value, architecture, layers, security, autoscaling, cost, observability, DR, reproduction, teardown, and trade-offs.
- [ ] Record a 3-5 minute walkthrough video.
- [ ] Write portfolio case study.
- [ ] Add four resume bullets.
- [ ] Pin the repository on GitHub.
- [ ] Update portfolio Services section to reference this repo as Terraform/IaC proof.

