#!/bin/bash

echo "🔍 Loki Stack Verification"
echo "=========================="
echo ""

echo "1️⃣ Checking Loki Status..."
kubectl get pods -n monitoring -l app=loki
echo ""

echo "2️⃣ Checking Promtail Status..."
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail
echo ""

echo "3️⃣ Testing Loki API..."
LOKI_READY=$(kubectl exec -n monitoring loki-0 -- wget -q -O- http://localhost:3100/ready 2>/dev/null)
if [ "$LOKI_READY" = "ready" ]; then
    echo "✅ Loki API is responding"
else
    echo "❌ Loki API is not ready"
fi
echo ""

echo "4️⃣ Checking log ingestion..."
# Query recent logs
LOG_COUNT=$(kubectl exec -n monitoring loki-0 -- wget -q -O- 'http://localhost:3100/loki/api/v1/query?query={namespace="app-workload"}' 2>/dev/null | grep -o '"status":"success"' | wc -l)
if [ "$LOG_COUNT" -gt 0 ]; then
    echo "✅ Loki is collecting logs from app-workload namespace"
else
    echo "⚠️  No logs found yet (may take a few minutes)"
fi
echo ""

echo "5️⃣ Services:"
kubectl get svc -n monitoring -l app=loki
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Loki Stack Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Loki: Log aggregation server"
echo "✅ Promtail: Log collector (DaemonSet on all nodes)"
echo "✅ Grafana Integration: Ready"
echo ""
echo "🔗 Access Logs in Grafana:"
echo "   1. kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
echo "   2. Open: http://localhost:3000"
echo "   3. Go to: Explore → Select 'Loki' datasource"
echo "   4. Query examples:"
echo "      {namespace=\"app-workload\"}"
echo "      {app=\"worker\"} |= \"error\""
echo "      {app=\"api\"} |= \"POST\""
echo ""
echo "📝 Useful LogQL Queries:"
echo "   # All logs from worker"
echo "   {app=\"worker\"}"
echo ""
echo "   # Error logs from API"
echo "   {app=\"api\"} |= \"error\""
echo ""
echo "   # Logs from specific pod"
echo "   {pod=\"worker-xxx\"}"
echo ""
echo "   # Rate of log lines"
echo "   rate({namespace=\"app-workload\"}[5m])"
