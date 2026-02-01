# Chaos Engineering Experiments

## Overview

This directory contains chaos engineering experiments to validate system resilience.

## Quick Start

```bash
# Run all experiments
./scripts/run-chaos-experiments.sh

# Or run individual experiments
./scripts/chaos-pod-kill.sh worker 60
./scripts/chaos-network-latency.sh worker 100ms 30
./scripts/chaos-validate-resilience.sh
```

## Experiments

### 1. Pod Kill Experiment

**Purpose**: Validate that the system recovers from pod failures

**Script**: `scripts/chaos-pod-kill.sh`

**Usage**:
```bash
./scripts/chaos-pod-kill.sh [target] [duration]
# Example: ./scripts/chaos-pod-kill.sh worker 60
```

**What it tests**:
- Kubernetes auto-healing
- PodDisruptionBudget enforcement
- HPA maintaining desired replicas
- Service continuity during pod restart

**Expected behavior**:
- Pod is killed
- Kubernetes immediately schedules a replacement
- System recovers within 30-60 seconds
- No service disruption (other pods handle traffic)

---

### 2. Network Latency Injection

**Purpose**: Test system behavior under degraded network conditions

**Script**: `scripts/chaos-network-latency.sh`

**Usage**:
```bash
./scripts/chaos-network-latency.sh [target] [latency] [duration]
# Example: ./scripts/chaos-network-latency.sh worker 100ms 30
```

**What it tests**:
- Application timeout handling
- Queue processing under latency
- Service degradation gracefully

**Expected behavior**:
- Processing rate decreases
- No crashes or errors
- System recovers immediately after latency removal

---

### 3. Full Resilience Validation

**Purpose**: Comprehensive system resilience test

**Script**: `scripts/chaos-validate-resilience.sh`

**What it tests**:
1. Baseline health
2. Single pod kill recovery
3. Multiple simultaneous pod kills
4. PodDisruptionBudget configuration
5. HPA configuration
6. Network policy enforcement
7. Service continuity during chaos
8. Final system health

**Output**: Generates a timestamped results file

---

## Using Chaos Mesh (Advanced)

### Install Chaos Mesh

```bash
kubectl create ns chaos-mesh
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace=chaos-mesh \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock
```

### Apply Chaos Experiments

```bash
# Network chaos
kubectl apply -f chaos/network-chaos.yaml

# Pod chaos
kubectl apply -f chaos/pod-chaos.yaml

# View chaos experiments
kubectl get networkchaos,podchaos -n app-workload

# Delete chaos
kubectl delete -f chaos/network-chaos.yaml
kubectl delete -f chaos/pod-chaos.yaml
```

---

## Monitoring During Chaos

### Grafana Dashboard
```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# Open: http://localhost:3000
```

**Metrics to watch**:
- Pod restart count
- Request latency
- Error rate
- Queue backlog
- Worker processing rate

### Prometheus Queries

**Pod restarts**:
```promql
rate(kube_pod_container_status_restarts_total{namespace="app-workload"}[5m])
```

**Service availability**:
```promql
up{namespace="app-workload"}
```

**Processing rate during chaos**:
```promql
rate(worker_tasks_processed_total[1m])
```

---

## Resilience Features Validated

### ✅ Auto-Healing
- Kubernetes automatically restarts failed pods
- Liveness probes detect unhealthy pods
- Readiness probes prevent traffic to unhealthy pods

### ✅ High Availability
- Multiple replicas (min 2)
- PodDisruptionBudgets prevent simultaneous failures
- Anti-affinity rules spread pods across nodes

### ✅ Auto-Scaling
- HPA scales based on CPU/memory
- Handles traffic spikes automatically
- Scales down during low load

### ✅ Network Security
- Network policies restrict traffic
- Only allowed connections permitted
- Defense in depth

### ✅ Graceful Degradation
- System continues operating under stress
- Queue buffers requests during pod restarts
- No data loss

---

## Expected Results

### Pod Kill
- ✅ Recovery time: < 60 seconds
- ✅ Zero data loss
- ✅ Service continuity maintained

### Network Latency
- ✅ No crashes
- ✅ Reduced throughput (expected)
- ✅ Immediate recovery after removal

### Multiple Failures
- ✅ PDB prevents all pods from being killed
- ✅ At least 1 pod always available
- ✅ HPA scales up if needed

---

## Troubleshooting

### Experiment fails to run
```bash
# Check pod status
kubectl get pods -n app-workload

# Check if tc is available (for network latency)
kubectl exec -it <pod> -n app-workload -- which tc
```

### System doesn't recover
```bash
# Check events
kubectl get events -n app-workload --sort-by='.lastTimestamp'

# Check HPA
kubectl describe hpa -n app-workload

# Check PDB
kubectl get pdb -n app-workload
```

### Chaos Mesh not working
```bash
# Check Chaos Mesh installation
kubectl get pods -n chaos-mesh

# Check chaos experiment status
kubectl describe networkchaos <name> -n app-workload
```

---

## Safety Notes

⚠️ **Important**:
- Run experiments in non-production environments first
- Monitor system during experiments
- Have rollback plan ready
- Inform team before running chaos experiments
- Start with small blast radius (one pod)
- Gradually increase chaos intensity

---

## Next Steps

1. **Automate**: Schedule regular chaos experiments
2. **Expand**: Add more failure scenarios
3. **Integrate**: Add to CI/CD pipeline
4. **Alert**: Configure alerts for chaos events
5. **Document**: Record learnings from each experiment
