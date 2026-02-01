#!/bin/bash
set -e

echo "📊 Deploying Loki Stack for Log Aggregation"
echo "============================================"
echo ""

# Add Grafana Helm repo
echo "1️⃣ Adding Grafana Helm repository..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki Stack (includes Loki + Promtail)
echo ""
echo "2️⃣ Installing Loki Stack..."
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=5Gi \
  --set promtail.enabled=true \
  --set grafana.enabled=false \
  --set loki.config.table_manager.retention_deletes_enabled=true \
  --set loki.config.table_manager.retention_period=168h \
  --wait \
  --timeout 5m

echo ""
echo "3️⃣ Waiting for Loki to be ready..."
kubectl wait --for=condition=ready pod -l app=loki -n monitoring --timeout=300s || true

echo ""
echo "4️⃣ Verifying deployment..."
kubectl get pods -n monitoring -l app=loki
kubectl get pods -n monitoring -l app=promtail

echo ""
echo "✅ Loki Stack deployed successfully!"
echo ""
echo "📊 Loki is now collecting logs from all pods"
echo ""
echo "🔗 Add Loki as datasource in Grafana:"
echo "   1. Access Grafana: kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
echo "   2. Go to Configuration → Data Sources"
echo "   3. Add Loki datasource"
echo "   4. URL: http://loki:3100"
echo "   5. Save & Test"
echo ""
echo "📝 Query logs in Grafana Explore:"
echo "   {namespace=\"app-workload\"}"
echo "   {app=\"worker\"}"
echo "   {app=\"api\"}"
