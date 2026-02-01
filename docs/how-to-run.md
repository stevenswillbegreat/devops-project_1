# How to Run - CueGrowth DevOps Project

## Prerequisites

- Docker
- kubectl
- Helm 3+
- Kind or Minikube (for local)
- Terraform (for cloud deployment)
- AWS CLI (for EKS deployment)

## Quick Start (Local with Kind)

### 1. Create Local Cluster
```bash
kind create cluster --config infra/kind-config.yaml --name cuegrowth
```

### 2. Deploy Infrastructure Components
```bash
# Create namespace
kubectl apply -f infra/namespaces.yaml

# Deploy Valkey
helm install valkey oci://registry-1.docker.io/bitnamicharts/redis \
  --namespace app-workload \
  --values infra/helm/valkey/values.yaml

# Deploy NATS
helm install nats nats/nats \
  --namespace app-workload \
  --values infra/helm/queue/values.yaml

# Create ConfigMap and Secrets
kubectl apply -f infra/shared-config.yaml
```

### 3. Build and Load Images
```bash
# Build API
cd services/api
docker build -t cuegrowth-api:latest .
kind load docker-image cuegrowth-api:latest --name cuegrowth

# Build Worker
cd ../worker
docker build -t cuegrowth-worker:latest .
kind load docker-image cuegrowth-worker:latest --name cuegrowth
```

### 4. Deploy Services
```bash
# Deploy API
helm install api infra/helm/api --namespace app-workload

# Deploy Worker
helm install worker infra/helm/worker --namespace app-workload
```

### 5. Apply Security and Operational Features
```bash
./scripts/apply-safe-improvements.sh
```

### 6. Deploy Observability Stack
```bash
chmod +x scripts/deploy-observability.sh
./scripts/deploy-observability.sh
```

### 7. Verify Deployment
```bash
kubectl get all -n app-workload
kubectl get networkpolicies,pdb,hpa -n app-workload
```

---

## Cloud Deployment (AWS EKS)

### 1. Deploy Infrastructure with Terraform

#### Development Environment
```bash
cd infra/terraform/environments/dev
terraform init
terraform plan
terraform apply
```

#### Production Environment
```bash
cd infra/terraform/environments/prod
terraform init
terraform plan
terraform apply
```

### 2. Configure kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name cuegrowth-cluster
```

### 3. Deploy Applications
```bash
# Follow steps 2-7 from Quick Start above
```

---

## Testing the System

### 1. Port Forward API
```bash
kubectl port-forward -n app-workload svc/api 8080:80
```

### 2. Submit a Task
```bash
curl -X POST http://localhost:8080/task \
  -H "Content-Type: application/json" \
  -d '{"payload": {"message": "Hello World", "priority": 1}}'
```

### 3. Check Stats
```bash
curl http://localhost:8080/stats
```

Expected response:
```json
{
  "valkey_keys_count": 5,
  "queue_backlog_length": 0,
  "worker_processed_count": 10
}
```

### 4. View Metrics
```bash
# Worker metrics
kubectl port-forward -n app-workload svc/worker 8000:8000
curl http://localhost:8000/metrics
```

---

## Access Monitoring

### Grafana
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```
- URL: http://localhost:3000
- User: admin
- Pass: admin123

### Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```
- URL: http://localhost:9090

### Import Dashboard
1. Open Grafana
2. Go to Dashboards → Import
3. Upload `infra/monitoring/grafana-dashboard.json`

---

## CI/CD Pipeline

### GitHub Actions
The pipeline automatically:
1. Runs tests
2. Builds Docker images
3. Scans for vulnerabilities
4. Deploys to cluster

### Manual Trigger
```bash
git push origin main
```

### ArgoCD (GitOps)
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Deploy application
kubectl apply -f infra/argocd-app.yaml

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

---

## Scaling

### Manual Scaling
```bash
# Scale API
kubectl scale deployment api -n app-workload --replicas=5

# Scale Worker
kubectl scale deployment worker -n app-workload --replicas=10
```

### Auto-Scaling (HPA)
Already configured! HPA will automatically scale based on CPU/Memory:
- API: 2-10 replicas
- Worker: 2-20 replicas

```bash
# Watch HPA in action
kubectl get hpa -n app-workload -w
```

---

## Cleanup

### Local (Kind)
```bash
kind delete cluster --name cuegrowth
```

### Cloud (EKS)
```bash
# Delete Kubernetes resources
helm uninstall api worker -n app-workload
kubectl delete namespace app-workload monitoring

# Destroy infrastructure
cd infra/terraform/environments/dev
terraform destroy
```

---

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for detailed debugging guides.

### Quick Checks
```bash
# Check pod status
kubectl get pods -n app-workload

# View logs
kubectl logs -f deployment/api -n app-workload
kubectl logs -f deployment/worker -n app-workload

# Check events
kubectl get events -n app-workload --sort-by='.lastTimestamp'

# Describe resources
kubectl describe deployment api -n app-workload
kubectl describe hpa api-hpa -n app-workload
```

---

## Environment Variables

### API Service
- `NATS_URL`: NATS connection string
- `VALKEY_HOST`: Valkey host
- `VALKEY_PASS`: Valkey password

### Worker Service
- `NATS_URL`: NATS connection string
- `VALKEY_HOST`: Valkey host
- `VALKEY_PASS`: Valkey password

All configured via ConfigMap and Secrets in `infra/shared-config.yaml`

---

## Performance Testing

### Load Test with hey
```bash
# Install hey
go install github.com/rakyll/hey@latest

# Run load test
hey -n 10000 -c 100 -m POST \
  -H "Content-Type: application/json" \
  -d '{"payload":{"test":true}}' \
  http://localhost:8080/task
```

### Watch Auto-Scaling
```bash
# Terminal 1: Watch HPA
watch kubectl get hpa -n app-workload

# Terminal 2: Watch pods
watch kubectl get pods -n app-workload

# Terminal 3: Run load test
hey -n 50000 -c 200 -m POST \
  -H "Content-Type: application/json" \
  -d '{"payload":{"test":true}}' \
  http://localhost:8080/task
```
