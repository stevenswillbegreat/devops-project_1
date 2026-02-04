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
# Create namespaces
kubectl create namespace app-workload
kubectl create namespace monitoring
kubectl create namespace ci

# Label monitoring namespace for NetworkPolicy
kubectl label namespace monitoring name=monitoring

# Deploy Valkey (Redis)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install valkey-redis bitnami/redis \
  --namespace app-workload \
  --set auth.password=securepassword123 \
  --set master.persistence.enabled=true \
  --set replica.replicaCount=2

# Deploy NATS
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm install nats nats/nats \
  --namespace app-workload \
  --set nats.jetstream.enabled=true \
  --set cluster.enabled=true \
  --set cluster.replicas=3
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

### 5. Apply Security Features
```bash
# Apply NetworkPolicies
kubectl apply -f infra/security/network-policies.yaml

# Apply PodSecurityStandards
kubectl label namespace app-workload pod-security.kubernetes.io/enforce=restricted

# Verify security
bash scripts/verify-security.sh
```

### 6. Deploy Observability Stack
```bash
# Install Prometheus Operator stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Deploy ServiceMonitors
kubectl apply -f infra/monitoring/service-monitors.yaml

# Deploy Valkey exporter
bash scripts/fix-metrics-final.sh

# Create NetworkPolicy for metrics scraping
kubectl apply -f infra/security/network-policies.yaml
```

### 7. Verify Deployment
```bash
kubectl get all -n app-workload
kubectl get networkpolicies,pdb,hpa -n app-workload
```

---

## Cloud Deployment (Multi-Cloud)

The project supports deployment to multiple cloud providers:
- **AWS EKS** (Primary)
- **Hetzner Cloud** (Cost-effective alternative)
- **OVH Public Cloud** (European option)

### Prerequisites

```bash
# Setup Terraform backend (one-time)
bash scripts/setup-terraform-backend.sh

# Configure cloud provider credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export HCLOUD_TOKEN="your-hetzner-token"  # Optional
export OVH_APPLICATION_KEY="your-ovh-key"  # Optional
```

---

### Option 1: AWS EKS Deployment

#### 1. Deploy Infrastructure
```bash
cd infra/terraform

# Initialize
terraform init

# Review plan
terraform plan -var="environment=dev" -var="aws_region=us-east-1"

# Apply
terraform apply -var="environment=dev" -var="aws_region=us-east-1"
```

#### 2. Configure kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name cuegrowth-cluster

# Verify connection
kubectl get nodes
```

#### 3. Deploy Applications
```bash
# Follow steps 2-7 from Quick Start above
```

---

### Option 2: Hetzner Cloud Deployment

#### 1. Deploy Infrastructure
```bash
cd infra/terraform/modules/hetzner-k8s

# Initialize
terraform init

# Apply
terraform apply -var="hcloud_token=$HCLOUD_TOKEN"
```

#### 2. Configure kubectl
```bash
# Get kubeconfig
terraform output -raw kubeconfig > ~/.kube/hetzner-config
export KUBECONFIG=~/.kube/hetzner-config

# Verify
kubectl get nodes
```

#### 3. Deploy Applications
```bash
# Follow steps 2-7 from Quick Start above
```

---

### Option 3: OVH Public Cloud Deployment

#### 1. Deploy Infrastructure
```bash
cd infra/terraform/modules/ovh-k8s

# Initialize
terraform init

# Apply
terraform apply \
  -var="ovh_application_key=$OVH_APPLICATION_KEY" \
  -var="ovh_application_secret=$OVH_APPLICATION_SECRET" \
  -var="ovh_consumer_key=$OVH_CONSUMER_KEY"
```

#### 2. Configure kubectl
```bash
# Get kubeconfig
terraform output -raw kubeconfig > ~/.kube/ovh-config
export KUBECONFIG=~/.kube/ovh-config

# Verify
kubectl get nodes
```

#### 3. Deploy Applications
```bash
# Follow steps 2-7 from Quick Start above
```

---

### Multi-Cloud Management with ArgoCD

ArgoCD can manage deployments across all clusters:

```bash
# Add AWS cluster
argocd cluster add cuegrowth-cluster --name aws-eks

# Add Hetzner cluster
argocd cluster add hetzner-k8s --name hetzner

# Add OVH cluster
argocd cluster add ovh-k8s --name ovh

# Deploy to specific cluster
kubectl apply -f ci/argocd-api.yaml  # Uses destination.name in manifest
```

---

### Terraform State Management

Each cloud provider has isolated state:

```
S3 Backend Structure:
├── aws-eks/terraform.tfstate       # AWS EKS state
├── hetzner-k8s/terraform.tfstate   # Hetzner state
└── ovh-k8s/terraform.tfstate       # OVH state
```

Benefits:
- **Isolated state** per cloud provider
- **Concurrent operations** across teams
- **State locking** via DynamoDB
- **Versioning** and encryption enabled

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
# Get password
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Port forward
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```
- URL: http://localhost:3000
- User: admin
- Pass: (from command above)

### Prometheus
```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```
- URL: http://localhost:9090
- Check targets: http://localhost:9090/targets

### Import Dashboard
1. Open Grafana (http://localhost:3000)
2. Click "+" → "Import dashboard"
3. Upload `infra/monitoring/dashboard-working-final.json`
4. Select "Prometheus" datasource
5. Click "Import"

Dashboard includes:
- API Request Rate
- Queue Backlog
- Worker Processing Rate
- Valkey Operations/sec
- Pod CPU/Memory Usage

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
# Quick setup
bash scripts/setup-argocd.sh

# Or manual setup:
kubectl create namespace ci
kubectl apply -n ci -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Deploy applications
kubectl apply -f ci/argocd-api.yaml
kubectl apply -f ci/argocd-worker.yaml
kubectl apply -f ci/argocd-nats.yaml
kubectl apply -f ci/argocd-valkey.yaml

# Access UI
bash scripts/access-argocd.sh
# Or manually:
kubectl port-forward svc/argocd-server -n ci 8080:443
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
helm uninstall api worker nats valkey-redis monitoring -n app-workload
kubectl delete namespace app-workload monitoring ci

# Destroy infrastructure
cd infra/terraform/environments/dev
terraform destroy
```

---

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
