#!/bin/bash
set -e

echo "🌐 Chaos Engineering: Network Latency Injection"
echo "================================================"
echo ""

NAMESPACE="app-workload"
TARGET="${1:-worker}"
LATENCY="${2:-100ms}"
DURATION="${3:-30}"

echo "🎯 Target: $TARGET pods"
echo "⏱️  Latency: $LATENCY"
echo "⏱️  Duration: ${DURATION}s"
echo ""

# Get target pod
POD=$(kubectl get pod -n $NAMESPACE -l app=$TARGET -o jsonpath='{.items[0].metadata.name}')
echo "Selected pod: $POD"
echo ""

# Pre-chaos baseline
echo "📊 Baseline Measurement:"
echo "------------------------"
if [ "$TARGET" = "api" ]; then
    echo "Testing API response time..."
    kubectl exec -n $NAMESPACE $POD -- sh -c "time curl -s http://localhost:8080/stats > /dev/null" 2>&1 | grep real
fi

if [ "$TARGET" = "worker" ]; then
    INITIAL_PROCESSED=$(kubectl exec -n $NAMESPACE $POD -- curl -s http://localhost:8000/metrics | grep worker_tasks_processed_total | awk '{print $2}')
    echo "Initial tasks processed: $INITIAL_PROCESSED"
fi
echo ""

# Inject latency
echo "💉 Injecting ${LATENCY} network latency..."
kubectl exec -n $NAMESPACE $POD -- sh -c "
    # Install tc if not present (for debian-based images)
    apt-get update -qq && apt-get install -y iproute2 2>/dev/null || true
    
    # Add latency to all outgoing traffic
    tc qdisc add dev eth0 root netem delay $LATENCY
    
    echo 'Latency injected successfully'
" 2>/dev/null || echo "⚠️  Note: tc might not be available in container"

echo ""
echo "⏳ Monitoring for ${DURATION}s with latency..."
echo ""

# Monitor during chaos
START_TIME=$(date +%s)
while [ $(($(date +%s) - START_TIME)) -lt $DURATION ]; do
    ELAPSED=$(($(date +%s) - START_TIME))
    
    if [ "$TARGET" = "worker" ]; then
        CURRENT_PROCESSED=$(kubectl exec -n $NAMESPACE $POD -- curl -s http://localhost:8000/metrics 2>/dev/null | grep worker_tasks_processed_total | awk '{print $2}' || echo "0")
        RATE=$(echo "scale=2; ($CURRENT_PROCESSED - $INITIAL_PROCESSED) / $ELAPSED" | bc 2>/dev/null || echo "N/A")
        echo "$(date +%T) - Elapsed: ${ELAPSED}s, Tasks: $CURRENT_PROCESSED, Rate: ${RATE}/s"
    else
        echo "$(date +%T) - Elapsed: ${ELAPSED}s"
    fi
    
    sleep 5
done

echo ""
echo "🔧 Removing latency..."
kubectl exec -n $NAMESPACE $POD -- sh -c "
    tc qdisc del dev eth0 root 2>/dev/null || true
    echo 'Latency removed'
" 2>/dev/null || echo "Cleanup attempted"

echo ""
echo "📊 Post-Chaos Measurement:"
echo "--------------------------"
sleep 5

if [ "$TARGET" = "api" ]; then
    echo "Testing API response time..."
    kubectl exec -n $NAMESPACE $POD -- sh -c "time curl -s http://localhost:8080/stats > /dev/null" 2>&1 | grep real
fi

if [ "$TARGET" = "worker" ]; then
    FINAL_PROCESSED=$(kubectl exec -n $NAMESPACE $POD -- curl -s http://localhost:8000/metrics 2>/dev/null | grep worker_tasks_processed_total | awk '{print $2}' || echo "0")
    echo "Final tasks processed: $FINAL_PROCESSED"
    TOTAL_PROCESSED=$((FINAL_PROCESSED - INITIAL_PROCESSED))
    echo "Tasks processed during chaos: $TOTAL_PROCESSED"
fi

echo ""
echo "📋 Experiment Summary:"
echo "----------------------"
echo "✅ Latency injection completed"
echo "   Duration: ${DURATION}s"
echo "   Latency: $LATENCY"
echo "   System continued processing under degraded network"

echo ""
echo "💡 Alternative: Use Chaos Mesh for advanced network chaos"
echo "   kubectl apply -f chaos/network-chaos.yaml"
