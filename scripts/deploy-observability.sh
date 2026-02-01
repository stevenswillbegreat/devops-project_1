#!/bin/bash
set -e

echo "📊 Deploying Observability Stack..."

# Create monitoring namespace
kubectl apply -f infra/monitoring/prometheus-setup.yaml

# Add Helm repos
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus + Grafana
echo ""
echo "1️⃣ Installing Prometheus & Grafana..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin123 \
  --wait

# Install Loki
echo ""
echo "2️⃣ Installing Loki..."
kubectl apply -f infra/monitoring/loki.yaml

# Wait for Loki
kubectl wait --for=condition=ready pod -l app=loki -n monitoring --timeout=300s

echo ""
echo "✅ Observability stack deployed!"
echo ""
echo "📊 Access Grafana:"
echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  URL: http://localhost:3000"
echo "  User: admin"
echo "  Pass: admin123"
echo ""
echo "📈 Access Prometheus:"
echo "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "  URL: http://localhost:9090"
