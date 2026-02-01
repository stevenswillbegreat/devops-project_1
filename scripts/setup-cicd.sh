#!/bin/bash

# Complete CI/CD Setup Script
set -e

echo "🚀 Setting up complete CI/CD pipeline..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check prerequisites
echo "Checking prerequisites..."
command -v kubectl >/dev/null 2>&1 || { print_error "kubectl is required but not installed."; exit 1; }
command -v helm >/dev/null 2>&1 || { print_error "helm is required but not installed."; exit 1; }
command -v aws >/dev/null 2>&1 || { print_warning "AWS CLI not found. Skipping AWS setup."; }

# 1. Install ArgoCD
echo "📦 Installing ArgoCD..."
kubectl apply -f infra/argocd-install.yaml
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
print_status "ArgoCD installed"

# 2. Expose ArgoCD UI
echo "🌐 Exposing ArgoCD UI..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
print_status "ArgoCD UI exposed"

# 3. Get ArgoCD admin password
echo "🔑 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"

# 4. Install ArgoCD Applications
echo "📋 Installing ArgoCD Applications..."
kubectl apply -f infra/argocd-apps.yaml
print_status "ArgoCD Applications configured"

# 5. Setup Helm repositories
echo "📚 Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jetstack https://charts.jetstack.io
helm repo update
print_status "Helm repositories added"

# 6. Install cert-manager
echo "🔒 Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
kubectl wait --for=condition=Ready pod -l app=cert-manager -n cert-manager --timeout=300s
print_status "cert-manager installed"

# 7. Install NGINX Ingress Controller
echo "🌍 Installing NGINX Ingress Controller..."
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.metrics.enabled=true \
  --set controller.podAnnotations."prometheus\.io/scrape"="true" \
  --set controller.podAnnotations."prometheus\.io/port"="10254"
print_status "NGINX Ingress Controller installed"

# 8. Install Istio (for advanced traffic management)
echo "🕸️ Installing Istio..."
curl -L https://istio.io/downloadIstio | sh -
export PATH="$PWD/istio-*/bin:$PATH"
istioctl install --set values.defaultRevision=default -y
kubectl label namespace app-workload istio-injection=enabled
print_status "Istio installed"

# 9. Deploy monitoring stack
echo "📊 Deploying monitoring stack..."
kubectl apply -f infra/monitoring/
print_status "Monitoring stack deployed"

# 10. Create GitHub secrets template
echo "🔐 Creating GitHub secrets template..."
cat > github-secrets-template.txt << EOF
# Add these secrets to your GitHub repository:
# Settings > Secrets and variables > Actions

AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key
HETZNER_KUBECONFIG=base64-encoded-kubeconfig-for-hetzner
OVH_KUBECONFIG=base64-encoded-kubeconfig-for-ovh

# To get base64 encoded kubeconfig:
# cat ~/.kube/config-hetzner | base64 -w 0
# cat ~/.kube/config-ovh | base64 -w 0
EOF
print_status "GitHub secrets template created"

# 11. Display access information
echo ""
echo "🎉 CI/CD Pipeline Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "ArgoCD Admin User: admin"
echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"
echo ""
echo "Grafana: kubectl port-forward svc/grafana -n observability 3000:80"
echo "Prometheus: kubectl port-forward svc/prometheus-server -n observability 9090:80"
echo ""
echo "📝 Next Steps:"
echo "1. Add GitHub secrets from github-secrets-template.txt"
echo "2. Update repository URLs in infra/argocd-apps.yaml"
echo "3. Push changes to trigger CI/CD pipeline"
echo "4. Access ArgoCD UI to monitor deployments"
echo ""
print_status "Setup completed successfully!"