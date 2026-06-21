# Phase 2 runbook — stand up GKE Autopilot and connect the pipeline

Goal: an ephemeral GKE Autopilot cluster that the Phase 1 pipeline deploys to,
with Workload Identity wired so pods use GCP services without static keys.

## Cost reality (single Autopilot cluster)
- **Control plane: effectively free.** The $74.40/month per-billing-account GKE
  credit covers one Autopilot cluster's $0.10/hr management fee.
- **Workload: per-pod requests only.** The reference app requests ~0.1 vCPU /
  128Mi total → pennies per hour. Use Spot Pods to cut it further.
- **Watch these (they are NOT free):**
  - `Service type: LoadBalancer` provisions a real GCP load balancer. Use
    `kubectl port-forward` for demos, or delete the Service before teardown.
  - Persistent disks / snapshots left behind after destroy.
  - Egress / inter-region traffic.
- Set a Cloud Billing budget alert before you apply.

## 0. Prerequisites (once)
    gcloud auth login
    gcloud config set project YOUR_PROJECT
    gcloud services enable container.googleapis.com compute.googleapis.com \
        secretmanager.googleapis.com

## 1. Apply (spin up)
    cd terraform
    terraform init
    terraform apply -var project_id=YOUR_PROJECT
    eval "$(terraform output -raw get_credentials)"   # kubeconfig context

## 2. Create the app's Kubernetes SA and bind Workload Identity
    kubectl create namespace production
    kubectl create serviceaccount reference-app -n production
    eval "$(terraform output -raw annotate_ksa)"      # links KSA -> Google SA
> In `chart/values.yaml`, set the pod's `serviceAccountName: reference-app`
> (add the field to the Deployment) so the app actually runs as that KSA.

## 3. Connect the GitLab Agent (this is what wires CI -> GKE)
1. In GitLab: **Operate -> Kubernetes clusters -> Connect a cluster**, name it
   `platform-agent` (must match `.gitlab/agents/platform-agent/config.yaml`).
   Copy the agent token it shows you.
2. Install the agent INTO the GKE cluster:

       helm repo add gitlab https://charts.gitlab.io
       helm upgrade --install platform-agent gitlab/gitlab-agent \
         --namespace gitlab-agent --create-namespace \
         --set config.token=<AGENT_TOKEN> \
         --set config.kasAddress=wss://kas.gitlab.com   # gitlab.com SaaS

3. The deploy jobs already target `KUBE_CONTEXT="$CI_PROJECT_PATH:platform-agent"`.

## 4. Deploy via the pipeline
Push to `main`. The pipeline builds, scans, signs, then `deploy-staging` runs
automatically; `deploy-prod` waits on the manual promotion gate.

Verify:
    kubectl get pods -n staging
    kubectl port-forward -n staging svc/reference-app 8080:80
    curl localhost:8080/   &&  curl localhost:8080/metrics

Confirm Workload Identity (no keys):
    kubectl -n production run wi-test --rm -it --restart=Never \
      --image=google/cloud-sdk:slim --overrides='{"spec":{"serviceAccountName":"reference-app"}}' \
      -- gcloud auth list   # should show the bound Google SA

## 5. Teardown (stop the meter)
    kubectl delete svc --all -A --field-selector spec.type=LoadBalancer  # kill any GCP LBs
    cd terraform && terraform destroy -var project_id=YOUR_PROJECT

## JD coverage added in Phase 2
Terraform IaC on GCP, GKE provisioning + operation, VPC-native networking,
Workload Identity Federation (least-privilege, no static keys), GitOps deploy
to Kubernetes, secrets foundation (Secret Manager add-on), cost-aware design.
