#!/bin/bash
set -e

echo "🎭 Chaos Engineering Experiment Suite"
echo "======================================"
echo ""

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make scripts executable
chmod +x "$SCRIPTS_DIR"/chaos-*.sh

echo "Available Experiments:"
echo "  1. Pod Kill"
echo "  2. Network Latency"
echo "  3. Full Resilience Validation"
echo "  4. All Experiments (Sequential)"
echo ""

read -p "Select experiment (1-4): " choice

case $choice in
    1)
        echo ""
        echo "Running Pod Kill Experiment..."
        "$SCRIPTS_DIR/chaos-pod-kill.sh" worker 60
        ;;
    2)
        echo ""
        echo "Running Network Latency Experiment..."
        "$SCRIPTS_DIR/chaos-network-latency.sh" worker 100ms 30
        ;;
    3)
        echo ""
        echo "Running Full Resilience Validation..."
        "$SCRIPTS_DIR/chaos-validate-resilience.sh"
        ;;
    4)
        echo ""
        echo "Running All Experiments..."
        echo ""
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Experiment 1/3: Pod Kill"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        "$SCRIPTS_DIR/chaos-pod-kill.sh" worker 60
        
        echo ""
        echo "Waiting 30s before next experiment..."
        sleep 30
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Experiment 2/3: Network Latency"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        "$SCRIPTS_DIR/chaos-network-latency.sh" worker 100ms 30
        
        echo ""
        echo "Waiting 30s before validation..."
        sleep 30
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Experiment 3/3: Resilience Validation"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        "$SCRIPTS_DIR/chaos-validate-resilience.sh"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Chaos experiments completed!"
echo ""
echo "📊 View results in Grafana:"
echo "   kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
echo ""
echo "📈 Check Prometheus metrics:"
echo "   kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090"
