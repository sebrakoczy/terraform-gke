# Phase 2 — GKE via Terraform

Stand up, demo, tear down (keeps cost near zero):

    terraform init
    terraform apply -var project_id=YOUR_PROJECT
    eval "$(terraform output -raw get_credentials)"
    # ... run the pipeline's deploy against this cluster ...
    terraform destroy -var project_id=YOUR_PROJECT

What this demonstrates from the JD: Terraform IaC on GCP, GKE provisioning,
Workload Identity Federation (least-privilege, no static keys), remote state.
