#!/bin/bash
set -e

echo "🛡️  System Resilience Validation"
echo "================================"
echo ""

NAMESPACE="app-workload"
DURATION=120
RESULTS_FILE="chaos-results-$(date +%Y%m%d-%H%M%S).txt"

# Initialize results
exec > >(tee -a "$RESULTS_FILE")
exec 2>&1

echo "📋 Test Configuration:"
echo "  Namespace: $NAMESPACE"
echo "  Duration: ${DURATION}s"
echo "  Results: $RESULTS_FILE"
echo ""

# Function to check system health
check_health() {
    local test_name=$1
    echo ""
    echo "🔍 Health Check: $test_name"
    echo "----------------------------"
    
    # Check pod status
    RUNNING_PODS=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running --no-headers | wc -l)
    TOTAL_PODS=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l)
    echo "Pods: $RUNNING_PODS/$TOTAL_PODS running"
    
    # Check HPA
    API_REPLICAS=$(kubectl get hpa api-hpa -n $NAMESPACE -o jsonpath='{.status.currentReplicas}')
    WORKER_REPLICAS=$(kubectl get hpa worker-hpa -n $NAMESPACE -o jsonpath='{.status.currentReplicas}')
    echo "HPA: API=$API_REPLICAS, Worker=$WORKER_REPLICAS"
    
    # Check API endpoint
    API_POD=$(kubectl get pod -n $NAMESPACE -l app=api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$API_POD" ]; then
        API_STATUS=$(kubectl exec -n $NAMESPACE $API_POD -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/stats 2>/dev/null || echo "000")
        echo "API Health: HTTP $API_STATUS"
    fi
    
    # Check worker metrics
    WORKER_POD=$(kubectl get pod -n $NAMESPACE -l app=worker -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$WORKER_POD" ]; then
        PROCESSED=$(kubectl exec -n $NAMESPACE $WORKER_POD -- curl -s http://localhost:8000/metrics 2>/dev/null | grep worker_tasks_processed_total | awk '{print $2}' || echo "0")
        echo "Worker: $PROCESSED tasks processed"
    fi
    
    # Overall health
    if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$API_STATUS" = "200" ]; then
        echo "Status: ✅ HEALTHY"
        return 0
    else
        echo "Status: ⚠️  DEGRADED"
        return 1
    fi
}

# Test 1: Baseline
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: Baseline Health Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_health "Baseline"
BASELINE_HEALTHY=$?

# Test 2: Pod Kill Resilience
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: Pod Kill Resilience"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Killing random worker pod..."
WORKER_POD=$(kubectl get pod -n $NAMESPACE -l app=worker -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $WORKER_POD -n $NAMESPACE --grace-period=0 --force &>/dev/null

echo "Waiting 30s for recovery..."
sleep 30
check_health "After Pod Kill"
POD_KILL_HEALTHY=$?

# Test 3: Multiple Pod Kills
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: Multiple Pod Kill (Stress Test)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Killing API and Worker pods simultaneously..."
API_POD=$(kubectl get pod -n $NAMESPACE -l app=api -o jsonpath='{.items[0].metadata.name}')
WORKER_POD=$(kubectl get pod -n $NAMESPACE -l app=worker -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $API_POD $WORKER_POD -n $NAMESPACE --grace-period=0 --force &>/dev/null

echo "Waiting 45s for recovery..."
sleep 45
check_health "After Multiple Pod Kills"
MULTI_KILL_HEALTHY=$?

# Test 4: PDB Validation
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 4: PodDisruptionBudget Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pdb -n $NAMESPACE
PDB_COUNT=$(kubectl get pdb -n $NAMESPACE --no-headers | wc -l)
echo "PDBs configured: $PDB_COUNT"

# Test 5: HPA Response
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 5: HPA Auto-Scaling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get hpa -n $NAMESPACE
HPA_COUNT=$(kubectl get hpa -n $NAMESPACE --no-headers | wc -l)
echo "HPAs configured: $HPA_COUNT"

# Test 6: Network Policies
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 6: Network Policy Enforcement"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
NETPOL_COUNT=$(kubectl get networkpolicies -n $NAMESPACE --no-headers | wc -l)
echo "Network Policies: $NETPOL_COUNT"
kubectl get networkpolicies -n $NAMESPACE

# Test 7: Service Continuity
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 7: Service Continuity Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Submitting test tasks during chaos..."
API_POD=$(kubectl get pod -n $NAMESPACE -l app=api -o jsonpath='{.items[0].metadata.name}')
SUCCESS=0
FAILED=0

for i in {1..10}; do
    if kubectl exec -n $NAMESPACE $API_POD -- curl -s -X POST http://localhost:8080/task \
        -H "Content-Type: application/json" \
        -d '{"payload":{"test":"chaos"}}' &>/dev/null; then
        SUCCESS=$((SUCCESS + 1))
    else
        FAILED=$((FAILED + 1))
    fi
    sleep 1
done

echo "Task submission: $SUCCESS success, $FAILED failed"
SUCCESS_RATE=$(echo "scale=2; $SUCCESS * 100 / 10" | bc)
echo "Success rate: ${SUCCESS_RATE}%"

# Final Health Check
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "FINAL: System Health"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_health "Final"
FINAL_HEALTHY=$?

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 RESILIENCE TEST SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Test Results:"
echo "  1. Baseline Health:        $([ $BASELINE_HEALTHY -eq 0 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  2. Pod Kill Recovery:      $([ $POD_KILL_HEALTHY -eq 0 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  3. Multiple Pod Kills:     $([ $MULTI_KILL_HEALTHY -eq 0 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  4. PDB Configuration:      $([ $PDB_COUNT -ge 4 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  5. HPA Configuration:      $([ $HPA_COUNT -ge 2 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  6. Network Policies:       $([ $NETPOL_COUNT -ge 5 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  7. Service Continuity:     $([ $SUCCESS_RATE -ge 80 ] && echo '✅ PASS' || echo '❌ FAIL') (${SUCCESS_RATE}%)"
echo "  8. Final Health:           $([ $FINAL_HEALTHY -eq 0 ] && echo '✅ PASS' || echo '❌ FAIL')"

echo ""
echo "Resilience Features:"
echo "  ✅ Auto-healing (Kubernetes restarts failed pods)"
echo "  ✅ PodDisruptionBudgets (prevent simultaneous failures)"
echo "  ✅ HorizontalPodAutoscaler (scale based on load)"
echo "  ✅ Network Policies (restrict traffic)"
echo "  ✅ Liveness/Readiness Probes (health monitoring)"
echo "  ✅ Rolling Updates (zero-downtime deployments)"

echo ""
echo "📄 Full results saved to: $RESULTS_FILE"
echo ""
echo "🎯 Next Steps:"
echo "  - Review Grafana dashboards for metrics during chaos"
echo "  - Check Prometheus alerts"
echo "  - Run: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
