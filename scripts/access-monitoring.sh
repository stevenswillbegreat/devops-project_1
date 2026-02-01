#!/bin/bash

echo "🎯 Observability Stack - Quick Access Guide"
echo "==========================================="
echo ""

echo "📊 GRAFANA"
echo "----------"
echo "Command: kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
echo "URL: http://localhost:3000"
echo "Username: admin"
echo "Password: prom-operator"
echo ""

echo "📈 PROMETHEUS"
echo "-------------"
echo "Command: kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090"
echo "URL: http://localhost:9090"
echo ""

echo "🔔 ALERTMANAGER"
echo "---------------"
echo "Command: kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093"
echo "URL: http://localhost:9093"
echo ""

echo "📊 Import Dashboard:"
echo "1. Access Grafana"
echo "2. Go to Dashboards → Import"
echo "3. Upload: infra/monitoring/grafana-dashboard.json"
echo ""

echo "🚀 Quick Start:"
echo "kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80 &"
echo "open http://localhost:3000"
