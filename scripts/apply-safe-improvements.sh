#!/bin/bash
set -e

echo "🚀 Applying Kubernetes improvements (gradual approach)..."

NAMESPACE="app-workload"

# 1. Apply Network Policies first (non-disruptive)
echo ""
echo "1️⃣ Applying Network Policies..."
kubectl apply -f infra/network-policies.yaml

# 2. Apply PodDisruptionBudgets (non-disruptive)
echo ""
echo "2️⃣ Applying PodDisruptionBudgets..."
kubectl apply -f infra/pdb.yaml

# 3. Apply HorizontalPodAutoscalers (non-disruptive)
echo ""
echo "3️⃣ Applying HorizontalPodAutoscalers..."
kubectl apply -f infra/hpa.yaml

echo ""
echo "✅ Non-disruptive changes applied!"
echo ""
echo "📊 Current status:"
kubectl get networkpolicies -n $NAMESPACE
echo ""
kubectl get pdb -n $NAMESPACE
echo ""
kubectl get hpa -n $NAMESPACE

echo ""
echo "⚠️  Note: Pod Security Standards and security contexts require pod restarts."
echo "   Run './scripts/apply-security-contexts.sh' when ready to update pods."
