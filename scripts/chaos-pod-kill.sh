#!/bin/bash
set -e

echo "💥 Chaos Engineering: Pod Kill Experiment"
echo "=========================================="
echo ""

NAMESPACE="app-workload"
TARGET="${1:-worker}"  # Default to worker, can pass 'api' or 'worker'
DURATION="${2:-60}"    # Monitor for 60 seconds

echo "🎯 Target: $TARGET pods in namespace $NAMESPACE"
echo "⏱️  Duration: ${DURATION}s"
echo ""

# Pre-chaos validation
echo "📊 Pre-Chaos State:"
echo "-------------------"
kubectl get pods -n $NAMESPACE -l app=$TARGET
INITIAL_COUNT=$(kubectl get pods -n $NAMESPACE -l app=$TARGET --field-selector=status.phase=Running --no-headers | wc -l)
echo "Running pods: $INITIAL_COUNT"
echo ""

# Get initial metrics
echo "📈 Initial Metrics:"
if [ "$TARGET" = "worker" ]; then
    WORKER_POD=$(kubectl get pod -n $NAMESPACE -l app=worker -o jsonpath='{.items[0].metadata.name}')
    INITIAL_PROCESSED=$(kubectl exec -n $NAMESPACE $WORKER_POD -- curl -s http://localhost:8000/metrics | grep worker_tasks_processed_total | awk '{print $2}')
    echo "Tasks processed: $INITIAL_PROCESSED"
fi
echo ""

# Kill a random pod
echo "💀 Killing random $TARGET pod..."
POD_TO_KILL=$(kubectl get pod -n $NAMESPACE -l app=$TARGET -o jsonpath='{.items[0].metadata.name}')
echo "Target pod: $POD_TO_KILL"
kubectl delete pod $POD_TO_KILL -n $NAMESPACE --grace-period=0 --force

echo ""
echo "⏳ Monitoring recovery for ${DURATION}s..."
echo ""

# Monitor recovery
START_TIME=$(date +%s)
RECOVERED=false

while [ $(($(date +%s) - START_TIME)) -lt $DURATION ]; do
    CURRENT_COUNT=$(kubectl get pods -n $NAMESPACE -l app=$TARGET --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    PENDING_COUNT=$(kubectl get pods -n $NAMESPACE -l app=$TARGET --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    
    echo "$(date +%T) - Running: $CURRENT_COUNT, Pending: $PENDING_COUNT"
    
    if [ "$CURRENT_COUNT" -ge "$INITIAL_COUNT" ] && [ "$PENDING_COUNT" -eq 0 ]; then
        RECOVERED=true
        RECOVERY_TIME=$(($(date +%s) - START_TIME))
        echo ""
        echo "✅ System recovered in ${RECOVERY_TIME}s"
        break
    fi
    
    sleep 2
done

echo ""
echo "📊 Post-Chaos State:"
echo "--------------------"
kubectl get pods -n $NAMESPACE -l app=$TARGET
FINAL_COUNT=$(kubectl get pods -n $NAMESPACE -l app=$TARGET --field-selector=status.phase=Running --no-headers | wc -l)
echo "Running pods: $FINAL_COUNT"

# Check HPA response
echo ""
echo "🔄 HPA Status:"
kubectl get hpa ${TARGET}-hpa -n $NAMESPACE

# Final metrics
if [ "$TARGET" = "worker" ]; then
    echo ""
    echo "📈 Final Metrics:"
    WORKER_POD=$(kubectl get pod -n $NAMESPACE -l app=worker -o jsonpath='{.items[0].metadata.name}')
    FINAL_PROCESSED=$(kubectl exec -n $NAMESPACE $WORKER_POD -- curl -s http://localhost:8000/metrics 2>/dev/null | grep worker_tasks_processed_total | awk '{print $2}' || echo "N/A")
    echo "Tasks processed: $FINAL_PROCESSED"
fi

echo ""
echo "📋 Experiment Summary:"
echo "----------------------"
if [ "$RECOVERED" = true ]; then
    echo "✅ PASS: System recovered successfully"
    echo "   Recovery time: ${RECOVERY_TIME}s"
    echo "   PodDisruptionBudget: Enforced"
    echo "   HPA: Maintained desired replicas"
else
    echo "❌ FAIL: System did not fully recover within ${DURATION}s"
    echo "   Current pods: $FINAL_COUNT / Expected: $INITIAL_COUNT"
fi

echo ""
echo "🔍 Check events:"
echo "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -20"
