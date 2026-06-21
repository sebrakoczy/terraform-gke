# Phase 4 runbook — security, policy & secrets

Run after the cluster (Phase 2) is up. Installs External Secrets + Kyverno and
applies the policy layer.

## 1. Create the secret (value stays out of Terraform state)
    cd terraform && terraform apply -var project_id=YOUR_PROJECT   # secret container + scoped IAM
    printf 's3cr3t-demo-value' | gcloud secrets versions add reference-app-api-key --data-file=-

## 2. Install the operators
    helm repo add external-secrets https://charts.external-secrets.io
    helm upgrade --install external-secrets external-secrets/external-secrets \
      -n external-secrets --create-namespace

    helm repo add kyverno https://kyverno.github.io/kyverno
    helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace

## 3. Apply the security manifests
Replace YOUR_PROJECT / YOUR_GROUP placeholders first, then:
    kubectl apply -f security/external-secrets-gcp.yaml
    kubectl apply -f security/kyverno-verify-images.yaml
    kubectl apply -f security/kyverno-hardening.yaml
    kubectl apply -f security/network-policies.yaml

## 4. Verify secrets sync
    kubectl get externalsecret -n production        # STATUS should be SecretSynced
    kubectl get secret app-secrets -n production -o jsonpath='{.data.API_KEY}' | base64 -d; echo
The app picks it up via envFrom (optional) on next rollout.

## 5. Verify policy enforcement
    # unsigned image -> DENIED by the verify-images policy:
    kubectl run rogue --image=nginx:latest -n production         # expect admission denial
    # privileged pod -> DENIED by restricted pod security:
    kubectl run priv --image=busybox -n production --privileged  # expect denial
    # the pipeline-signed reference-app image -> ALLOWED.

## 6. Confirm the keyless identity matches (do this once after the first signed push)
    cosign verify \
      --certificate-identity-regexp "https://gitlab.com/YOUR_GROUP/gke-reference-platform.*" \
      --certificate-oidc-issuer "https://gitlab.com" \
      registry.gitlab.com/YOUR_GROUP/gke-reference-platform/reference-app:<sha>
If the identity differs, update subjectRegExp in kyverno-verify-images.yaml to match.

## Notes / gotchas
- The verify policy only checks images matching imageReferences (your registry),
  so system and operator images are never blocked.
- Hardening policies are scoped to the production/staging namespaces, so system
  components are unaffected. The app chart already meets the restricted profile.
- In production, install ESO + Kyverno via ArgoCD/GitLab Agent (declarative), and
  drop the broad project-level secretAccessor in iam.tf in favor of the scoped grant.

## JD coverage added in Phase 4
Secrets management, least-privilege IAM, configuration hardening, policy-as-code,
network segmentation, supply-chain enforcement, auditable & repeatable security.
