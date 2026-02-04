#!/bin/bash

echo "=== Creating Mock Metrics for Dashboard ==="
echo ""

# Create worker service first
echo "1. Creating worker service..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: worker
  namespace: app-workload
  labels:
    app: worker
spec:
  selector:
    app: worker
  ports:
  - name: http
    port: 8000
    targetPort: 8000
EOF

echo "   ✅ Worker service created"
echo ""

# Install Valkey exporter
echo "2. Installing Valkey metrics exporter..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: valkey-exporter
  namespace: app-workload
spec:
  replicas: 1
  selector:
    matchLabels:
      app: valkey-exporter
  template:
    metadata:
      labels:
        app: valkey-exporter
    spec:
      containers:
      - name: exporter
        image: oliver006/redis_exporter:latest
        env:
        - name: REDIS_ADDR
          value: "valkey-redis-master:6379"
        ports:
        - containerPort: 9121
          name: metrics
---
apiVersion: v1
kind: Service
metadata:
  name: valkey-exporter
  namespace: app-workload
  labels:
    app: valkey-exporter
spec:
  selector:
    app: valkey-exporter
  ports:
  - name: metrics
    port: 9121
    targetPort: 9121
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: valkey-exporter
  namespace: monitoring
  labels:
    release: monitoring
spec:
  selector:
    matchLabels:
      app: valkey-exporter
  namespaceSelector:
    matchNames:
      - app-workload
  endpoints:
  - port: metrics
    path: /metrics
EOF

echo "   ✅ Valkey exporter installed"
echo ""

echo "3. Waiting for exporter to start..."
sleep 10

echo ""
echo "✅ Metrics collection configured!"
echo ""
echo "Wait 30-60 seconds for Prometheus to scrape metrics, then:"
echo "  1. Go to: http://localhost:3000"
echo "  2. Open: CueGrowth Microservices Dashboard"
echo "  3. Data should appear in:"
echo "     - Worker Processing Rate ✓"
echo "     - Valkey Operations/sec ✓"
echo "     - Pod CPU/Memory ✓"
echo ""
echo "Note: API metrics won't show until API pods are fixed"
echo ""
