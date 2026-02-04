# ArgoCD ApplicationSet

ApplicationSet provides automated multi-cluster deployment management.

## Benefits

- **Single Source of Truth**: One manifest manages all environments
- **Automatic Scaling**: Add new clusters without manual configuration
- **Consistent Deployment**: Same configuration across all environments
- **Reduced Duplication**: DRY principle for multi-cloud deployments

## Deployment

```bash
# Install ApplicationSet
kubectl apply -f infra/argocd-applicationset.yaml

# Verify ApplicationSet
kubectl get applicationset -n argocd

# Check generated Applications
kubectl get applications -n argocd
```

## ApplicationSets Included

### 1. multi-cloud-api
Deploys API service to AWS, Hetzner, and OVH with environment-specific configurations.

### 2. multi-cloud-worker
Deploys worker service across all clusters with appropriate replica counts.

### 3. observability-stack
Deploys monitoring stack to all clusters for unified observability.

## Advanced Options

### Git-based Generator
Automatically detects Helm charts in repository:
```bash
kubectl apply -f infra/argocd-applicationset-advanced.yaml
```

### Cluster Generator
Automatically deploys to all registered clusters:
- Discovers clusters via ArgoCD cluster secrets
- No manual cluster list maintenance

## Customization

Edit `infra/argocd-applicationset.yaml` to:
- Add new clusters
- Modify resource allocations
- Change sync policies
- Update value files