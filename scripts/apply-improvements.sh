#!/bin/bash
set -e

echo "🚀 Applying Kubernetes security and operational improvements..."

NAMESPACE="app-workload"

echo "📋 Current context:"
kubectl config current-context

# 1. Apply Pod Security Standards
echo ""
echo "1️⃣ Applying Pod Security Standards..."
kubectl apply -f infra/pod-security-standards.yaml

# 2. Apply Network Policies
echo ""
echo "2️⃣ Applying Network Policies..."
kubectl apply -f infra/network-policies.yaml

# 3. Apply PodDisruptionBudgets
echo ""
echo "3️⃣ Applying PodDisruptionBudgets..."
kubectl apply -f infra/pdb.yaml

# 4. Apply HorizontalPodAutoscalers
echo ""
echo "4️⃣ Applying HorizontalPodAutoscalers..."
kubectl apply -f infra/hpa.yaml

# 5. Upgrade API Helm chart
echo ""
echo "5️⃣ Upgrading API deployment..."
helm upgrade api infra/helm/api \
  --namespace $NAMESPACE \
  --wait \
  --timeout 5m

# 6. Upgrade Worker Helm chart
echo ""
echo "6️⃣ Upgrading Worker deployment..."
helm upgrade worker infra/helm/worker \
  --namespace $NAMESPACE \
  --wait \
  --timeout 5m

# 7. Verify
echo ""
echo "✅ Verifying deployments..."
kubectl get pods -n $NAMESPACE
kubectl get networkpolicies -n $NAMESPACE
kubectl get pdb -n $NAMESPACE
kubectl get hpa -n $NAMESPACE

echo ""
echo "🎉 All changes applied successfully!"
