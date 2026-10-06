# Diagram prompts

Three images for `docs/index.html`. Same style as the portfolio case studies
(`~/Desktop/portfolio/prompts/diagrams/style.md`).

1. New ChatGPT chat. Paste the **Style block**, wait for the confirmation.
2. Paste the **Context** block. ChatGPT replies "got it" and draws nothing.
3. Send each diagram prompt as its own message.
4. Save each image to its "Save as" path. Until a file exists, the page shows a dashed slot.

Check every label letter by letter. Watch `argocd-gitops-config`, `eks-paved-road`,
`REPLACE_ME`, `root-app.yaml`, `ExternalSecret` and `SecretStore`.
For a wrong label, reply: Keep everything exactly the same. Only change the label "X" to "Y".

## Style block (paste first)

```
You are a Diagram Architect AI. Every diagram in this chat follows this style exactly.

1. Canvas: landscape 3:2. Off-white background with a subtle light-grey graph-paper grid.
2. Strokes: hand-drawn, sketchy lines, slightly rough, like Excalidraw.
3. Shapes:
   - Dashed rounded boxes with light pastel fills group zones:
     pastel green = private / safe / the fix,
     pastel blue = cloud account, region, VPC or cluster,
     pastel purple = people, identity and CI,
     pastel yellow = end users and the product itself,
     pale grey = public internet, or the old / rejected approach.
   - Each service is a small flat 2D icon centred above its label. Use recognisable AWS / Google
     Cloud / Kubernetes / GitHub / GitLab / vendor-style icons where one exists. Generic things
     (person, phone, laptop, globe, database, key, file, shield) get simple flat icons.
4. Typography: a handwritten font (Virgil / Caveat style), dark charcoal. Short labels only.
5. Flow:
   - Dashed arrows show data/access flow.
   - Numbered orange circle badges (1, 2, 3...) mark the order of steps.
   - Small curved annotation arrows point to short inline notes (max 8 words each).
   - A blocked or rejected path is a dashed grey arrow that ends in a red ✕. A rejected box is
     grey and struck through.
   - The fix gets a small green check.
6. Layout: strict alignment, generous white space, nothing crammed.

TEXT RULES: use ONLY the labels I give, spelled exactly as written. No title, no legend, no
watermark, no extra text, no invented numbers, no company or client names.

Next I'll send a short project context, then one diagram per message. Don't generate anything
until I ask for a diagram. Confirm you understand.
```

## Context (paste second)

```
Project context. Don't draw anything yet, just read it and reply "got it".

A personal AWS lab: an EKS cluster where Terraform builds the infrastructure and Argo CD owns
everything running inside it.

- Network: one VPC across two Availability Zones. Public subnets hold one NAT gateway. Private
  subnets hold the EKS worker nodes: one small spot instance node group.
- The EKS cluster has an OIDC provider. That lets a Kubernetes ServiceAccount assume an AWS IAM
  role with short-lived credentials ("IRSA"). There are no stored AWS keys in the cluster.
- Two Git repos. "argocd-gitops-config" holds the shared Argo CD Applications and Kubernetes
  manifests, with three placeholders in them: role ARN, region and secret name.
  "eks-paved-road" holds the Terraform and a small Kustomize overlay that references the shared
  manifests (does not copy them) and fills in the three values.
- Argo CD uses an "app-of-apps": one root Application creates three child Applications.
- The catch: if you apply the shared repo's own root Application, Argo CD fetches the children
  straight from the shared repo, unpatched, so they deploy with the placeholders. The fix is a
  root Application in eks-paved-road that points at the overlay, so the children arrive patched.
- Secrets: the database password lives only in AWS Secrets Manager. The External Secrets
  Operator (ESO) assumes an IAM role through IRSA, reads that one secret, and writes it into a
  Kubernetes Secret. The web pods read it as environment variables.
- Argo CD applies things in "sync waves": wave 1 installs ESO, wave 2 the SecretStore and
  ExternalSecret, wave 3 the web app.
- Nothing is exposed with a load balancer. The operator reaches the Argo CD UI with
  kubectl port-forward.
```

## Diagram 1 · Hero
Save as `docs/images/eks-architecture.png`

```
Generate Diagram 1. Story: Terraform builds the cluster once, then Git drives everything inside
it, and the app gets its secret without any stored keys.

FAR LEFT, stacked vertically:
- Top (pastel purple zone): person icon "Operator", with a Terraform icon "Terraform" next to it.
- Bottom (pastel purple zone): two GitHub icons side by side, "argocd-gitops-config" and
  "eks-paved-road".

RIGHT: big dashed pastel-blue box "AWS · us-east-1". Inside it:
- A dashed pastel-blue box "VPC · 2 AZs" taking most of the space. Along its top edge a pale
  band "Public subnets" with a NAT gateway icon "NAT gateway", note "only one".
- Inside the VPC, a pastel-green box "Private subnets" holding a Kubernetes/EKS icon box
  "EKS cluster", note "spot node group". Inside the EKS box, three small items in a row:
  Argo CD icon "Argo CD", ESO icon (generic shield/key) "External Secrets", pod icon "web".
- Outside the VPC but inside the AWS box, on the right: Secrets Manager icon
  "Secrets Manager", and below it an IAM icon "IRSA role", note "one secret only".

ARROWS:
- Terraform → AWS box: badge 1, label "terraform apply"
- argocd-gitops-config and eks-paved-road → Argo CD: badge 2, label "git pull"
- Argo CD → External Secrets and → web: thin dashed arrows, label "syncs"
- External Secrets → IRSA role: badge 3, label "assume, no keys"
- IRSA role → Secrets Manager: dashed arrow, label "GetSecretValue"
- External Secrets → web: badge 4, label "K8s Secret"
- Operator → Argo CD: thin dashed grey arrow, label "port-forward"

BOTTOM RIGHT, next to the AWS box: a small grey struck-through load balancer icon
"LoadBalancer" with a red ✕, and a small grey struck-through key icon "AWS access keys" with a
red ✕.

Keep the composition centred with empty graph paper around the edges.
```

## Diagram 2 · Where the placeholders get filled
Save as `docs/images/eks-root-app.png`

```
Generate Diagram 2. Story: applying the shared root deploys the placeholders; a root in the
environment's own repo deploys the real values.

TWO PANELS SIDE BY SIDE.

LEFT PANEL (pale grey, rejected), heading label "shared root":
- top: GitHub icon "argocd-gitops-config", with a small file icon below it "root-app.yaml"
- arrow down to Argo CD icon "Argo CD"
- arrow from Argo CD back UP to the GitHub icon, label "fetches children"
- arrow down to three small boxes in a row: "ESO", "secrets", "web"
- the "ESO" and "secrets" boxes each carry a small tag "REPLACE_ME"
- the three boxes are grey and struck through, with a red ✕ and note "deploys the placeholders"

RIGHT PANEL (pastel green, the fix), heading label "eks-paved-road root":
- top left: GitHub icon "eks-paved-road", with a small file icon below it "root-app.yaml"
- top right: GitHub icon "argocd-gitops-config", note "referenced, not copied"
- middle: a box "Kustomize overlay", with three small chips inside it: "role ARN", "region",
  "secret name"
- dashed arrow from argocd-gitops-config into the overlay box
- arrow from the overlay box down to Argo CD icon "Argo CD"
- arrow down to three small boxes in a row: "ESO", "secrets", "web", with a green check and note
  "real values"

Badges 1, 2, 3 on the right panel's steps, top to bottom (repo, overlay, Argo CD). No badges on
the left panel.
```

## Diagram 3 · The secret path
Save as `docs/images/eks-secret-path.png`

```
Generate Diagram 3. Story: Argo CD installs things in order, and the secret travels from AWS to
the pod with no stored keys.

TOP: pastel-blue box "EKS cluster" holding three columns, left to right, each a dashed rounded
box with an orange badge at its top:
1. Badge 1, "wave 1": ESO icon (generic shield/key) "External Secrets", with a small
   ServiceAccount icon below it "ServiceAccount", note "annotated with role ARN".
2. Badge 2, "wave 2": two small file icons "SecretStore" and "ExternalSecret", and below them a
   key icon "K8s Secret".
3. Badge 3, "wave 3": pod icon "web", note "envFrom".
Arrow from "K8s Secret" → "web".

BOTTOM: pastel-purple strip "AWS". Inside it, left to right:
- OIDC/identity icon "OIDC provider"
- AWS STS icon "STS"
- IAM role icon "IRSA role", note "trusts one ServiceAccount"
- Secrets Manager icon "Secrets Manager", note "one secret, value set by hand"

ARROWS between the two areas:
- ServiceAccount → STS: dashed arrow, label "token"
- STS → IRSA role: dashed arrow, label "short-lived creds"
- IRSA role → Secrets Manager: dashed arrow, label "GetSecretValue"
- Secrets Manager → "K8s Secret": dashed arrow up, label "every 1h"

RIGHT EDGE: a small grey struck-through key icon "static AWS keys" with a red ✕, and a small grey
struck-through Git icon "secret in Git" with a red ✕.
```
