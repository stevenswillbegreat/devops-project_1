# Troubleshooting Guide

## 1. Why might a Valkey cluster in Kubernetes experience split-brain, and how do you prevent it?

### Causes:
- **Network partitions**: Temporary network issues between pods/nodes
- **Node failures**: Master node becomes unreachable but still running
- **Quorum loss**: Not enough replicas to elect a new master
- **DNS resolution delays**: Service discovery issues during failover
- **Resource starvation**: CPU/memory pressure causing timeouts

### Prevention Strategies:

1. **Use Sentinel with proper quorum**:
   ```yaml
   sentinel:
     enabled: true
     quorum: 2  # Majority of sentinels must agree
   ```

2. **Pod Anti-Affinity**:
   ```yaml
   affinity:
     podAntiAffinity:
       requiredDuringSchedulingIgnoredDuringExecution:
       - topologyKey: kubernetes.io/hostname
   ```

3. **Network Policies**: Ensure stable network connectivity
4. **Resource Guarantees**: Set proper requests/limits
5. **Health Checks**: Aggressive liveness/readiness probes
6. **PodDisruptionBudgets**: Prevent simultaneous pod evictions

---

## 2. Worker pods constantly restart with "connection refused to queue service"

### 5 Possible Root Causes:

#### 1. **DNS Resolution Failure**
**Diagnosis**:
```bash
kubectl exec -it worker-pod -- nslookup nats.app-workload.svc
kubectl get svc -n app-workload
```
**Fix**: Verify service exists and DNS is working

#### 2. **Network Policy Blocking Traffic**
**Diagnosis**:
```bash
kubectl get networkpolicies -n app-workload
kubectl describe networkpolicy worker-to-nats
```
**Fix**: Add network policy allowing worker → NATS

#### 3. **NATS Not Ready**
**Diagnosis**:
```bash
kubectl get pods -n app-workload -l app=nats
kubectl logs nats-0 -n app-workload
```
**Fix**: Check NATS logs, ensure it's fully started

#### 4. **Wrong Service Port**
**Diagnosis**:
```bash
kubectl get svc nats -n app-workload -o yaml
# Check if port 4222 is exposed
```
**Fix**: Verify NATS_URL environment variable matches service port

#### 5. **Startup Race Condition**
**Diagnosis**:
```bash
kubectl describe pod worker-pod
# Check if worker starts before NATS is ready
```
**Fix**: Add initContainer or increase initialDelaySeconds in readiness probe

---

## 3. Deployment rollout stuck - kubectl rollout status never completes

### Step-by-Step Investigation:

#### Step 1: Check Rollout Status
```bash
kubectl rollout status deployment/api -n app-workload
kubectl get rs -n app-workload
```

#### Step 2: Inspect New ReplicaSet
```bash
kubectl describe rs <new-replicaset-name> -n app-workload
```

#### Step 3: Check Pod Status
```bash
kubectl get pods -n app-workload -l app=api
kubectl describe pod <pending-pod> -n app-workload
```

#### Step 4: Common Issues to Check:

**A. Image Pull Failure**:
```bash
kubectl get events -n app-workload --sort-by='.lastTimestamp'
# Look for: "Failed to pull image" or "ImagePullBackOff"
```

**B. Readiness Probe Failing**:
```bash
kubectl logs <pod-name> -n app-workload
# Check if /stats endpoint is responding
```

**C. Resource Constraints**:
```bash
kubectl describe nodes
# Look for: "Insufficient cpu" or "Insufficient memory"
```

**D. PodDisruptionBudget Blocking**:
```bash
kubectl get pdb -n app-workload
# Check if minAvailable prevents old pods from terminating
```

**E. Pod Security Policy Violation**:
```bash
kubectl get events -n app-workload | grep -i "forbidden"
```

#### Step 5: Force Rollback if Needed
```bash
kubectl rollout undo deployment/api -n app-workload
```

---

## 4. API latency spikes every 5 minutes

### Kubernetes-Level Causes:

#### 1. **Liveness Probe Killing Pods**
- Probe interval: 5 minutes
- Pod restart causes brief downtime
**Check**: `kubectl describe pod api-pod | grep Liveness`

#### 2. **HPA Scaling Events**
- HPA evaluation period causing pod churn
**Check**: `kubectl get hpa -n app-workload -w`

#### 3. **ConfigMap/Secret Reload**
- Sidecar reloading configuration
**Check**: `kubectl logs api-pod -c config-reloader`

#### 4. **Garbage Collection**
- Kubelet evicting pods due to disk pressure
**Check**: `kubectl describe node | grep -A 5 "Conditions"`

### Cloud-Level Causes:

#### 5. **EBS Volume Throttling**
- IOPS limits hit periodically
**Check**: CloudWatch metrics for VolumeReadOps/VolumeWriteOps

#### 6. **NAT Gateway Throttling**
- Connection tracking table full
**Check**: CloudWatch NAT Gateway metrics

#### 7. **AWS API Rate Limiting**
- Service mesh calling AWS APIs
**Check**: CloudTrail for ThrottlingException

#### 8. **Scheduled Node Maintenance**
- Cloud provider draining nodes
**Check**: `kubectl get events --all-namespaces | grep -i drain`

### Investigation Commands:
```bash
# Check pod restarts
kubectl get pods -n app-workload -o wide

# Monitor HPA
kubectl get hpa -n app-workload -w

# Check node conditions
kubectl describe nodes | grep -A 10 "Conditions"

# View metrics
kubectl top pods -n app-workload
kubectl top nodes
```

---

## 5. Safe Rollbacks in Microservice + Queue + Worker Architecture

### Strategy:

#### Phase 1: Pre-Rollback Validation
```bash
# 1. Identify the issue
kubectl logs deployment/api -n app-workload --tail=100

# 2. Check current version
kubectl get deployment api -n app-workload -o yaml | grep image:

# 3. Verify queue state
kubectl exec -it worker-pod -- curl http://api/stats
```

#### Phase 2: Rollback Order (Critical!)

**Order matters to prevent data loss:**

1. **Rollback Worker First**
   ```bash
   kubectl rollout undo deployment/worker -n app-workload
   kubectl rollout status deployment/worker -n app-workload
   ```
   *Why*: Workers process messages. Old workers must handle new message formats.

2. **Wait for Queue to Drain**
   ```bash
   # Monitor queue backlog
   watch kubectl exec -it worker-pod -- curl http://api/stats
   ```

3. **Rollback API Second**
   ```bash
   kubectl rollout undo deployment/api -n app-workload
   kubectl rollout status deployment/api -n app-workload
   ```

#### Phase 3: Verification
```bash
# Test end-to-end
curl -X POST http://api/task -d '{"payload": {"test": true}}'

# Check metrics
kubectl exec -it worker-pod -- curl http://localhost:8000/metrics
```

### Backward Compatibility Rules:

1. **Message Format**: Always support old message schemas
2. **Database Schema**: Use expand-contract pattern
3. **API Versioning**: Keep old endpoints during transition
4. **Feature Flags**: Toggle new features without redeployment

### Automated Rollback Triggers:

```yaml
# In deployment.yaml
spec:
  progressDeadlineSeconds: 600
  strategy:
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
```

### Circuit Breaker Pattern:
```python
# In worker code
if error_rate > 0.5:
    # Stop processing, alert ops
    raise Exception("High error rate, triggering rollback")
```

---

## Quick Reference Commands

```bash
# Check everything
kubectl get all,pdb,hpa,networkpolicies -n app-workload

# Logs
kubectl logs -f deployment/api -n app-workload
kubectl logs -f deployment/worker -n app-workload

# Events
kubectl get events -n app-workload --sort-by='.lastTimestamp'

# Metrics
kubectl top pods -n app-workload
kubectl top nodes

# Rollback
kubectl rollout undo deployment/api -n app-workload
kubectl rollout history deployment/api -n app-workload
```
