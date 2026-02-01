# Observability Stack - Deployment Summary

## ✅ Successfully Deployed

### 1. Prometheus Stack
- **Status**: Running
- **Components**:
  - Prometheus Server (metrics collection)
  - Node Exporter (node metrics)
  - Kube State Metrics (K8s metrics)
  - Alertmanager (alerting)
- **Access**: `kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090`

### 2. Grafana
- **Status**: Running
- **Version**: Included with kube-prometheus-stack
- **Access**: `kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80`
- **Credentials**:
  - Username: `admin`
  - Password: `prom-operator`

### 3. ServiceMonitors
- **Location**: `infra/monitoring/service-monitors.yaml`
- **Configured for**: API and Worker services
- **Metrics Endpoints**:
  - Worker: `:8000/metrics`
  - API: `:8080/metrics` (if implemented)

## 📊 Available Metrics

### Worker Metrics
```
worker_tasks_processed_total - Total tasks processed
worker_tasks_errors_total - Total processing errors
```

### Kubernetes Metrics
```
container_cpu_usage_seconds_total - CPU usage
container_memory_usage_bytes - Memory usage
kube_pod_status_phase - Pod status
kube_deployment_status_replicas - Deployment replicas
```

### Valkey Metrics
```
redis_commands_processed_total - Commands processed
redis_connected_clients - Connected clients
redis_memory_used_bytes - Memory usage
```

## 🎯 Quick Access Commands

### Access Grafana
```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# Open: http://localhost:3000
# User: admin, Pass: prom-operator
```

### Access Prometheus
```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Open: http://localhost:9090
```

### Import Dashboard
1. Access Grafana at http://localhost:3000
2. Navigate to: Dashboards → Import
3. Upload: `infra/monitoring/grafana-dashboard.json`
4. Select Prometheus datasource
5. Click Import

## 📈 Dashboard Panels

The provided dashboard includes:
1. **API Request Rate** - HTTP requests per second
2. **Queue Backlog** - Number of pending tasks
3. **Worker Processing Rate** - Tasks processed per second
4. **Valkey Operations** - Redis operations per second
5. **Pod CPU Usage** - CPU usage by pod
6. **Pod Memory Usage** - Memory usage by pod

## 🔍 Querying Metrics

### Example Prometheus Queries

**Worker processing rate:**
```promql
rate(worker_tasks_processed_total[5m])
```

**Pod CPU usage:**
```promql
rate(container_cpu_usage_seconds_total{namespace="app-workload"}[5m])
```

**Pod memory usage:**
```promql
container_memory_usage_bytes{namespace="app-workload"}
```

**HPA current replicas:**
```promql
kube_horizontalpodautoscaler_status_current_replicas{namespace="app-workload"}
```

## 🚨 Alerting

Alertmanager is configured and running. To add custom alerts:

1. Create PrometheusRule:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-alerts
  namespace: monitoring
spec:
  groups:
  - name: app
    rules:
    - alert: HighErrorRate
      expr: rate(worker_tasks_errors_total[5m]) > 0.1
      annotations:
        summary: "High error rate detected"
```

2. Apply: `kubectl apply -f alert-rules.yaml`

## 📝 Next Steps

1. **Import Dashboard**: Upload the Grafana dashboard JSON
2. **Configure Alerts**: Set up alerting rules
3. **Add Loki** (Optional): For log aggregation
4. **Configure Retention**: Adjust Prometheus retention period
5. **Set up Remote Storage** (Optional): For long-term metrics storage

## 🔧 Troubleshooting

### Metrics not showing up?
```bash
# Check ServiceMonitor
kubectl get servicemonitor -n app-workload

# Check if Prometheus is scraping
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Go to: http://localhost:9090/targets
```

### Grafana login issues?
```bash
# Get admin password
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

### Pod not being monitored?
```bash
# Ensure pod has metrics endpoint
kubectl exec -it <pod-name> -n app-workload -- curl localhost:8000/metrics
```

## 📚 Resources

- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/
- kube-prometheus-stack: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
