#!/bin/bash
set -e # Exit on error

echo "🔹 1. Building and Loading Images..."
docker build -t cuegrowth-api:latest ./services/api
docker build -t cuegrowth-worker:latest ./services/worker
kind load docker-image cuegrowth-api:latest --name cuegrowth
kind load docker-image cuegrowth-worker:latest --name cuegrowth

echo "🔹 2. Deploying via Helm..."
# [cite: 87] Deploy via helm upgrade
helm upgrade --install api ./infra/helm/api --namespace app-workload --set image.tag=latest --set image.pullPolicy=Never
helm upgrade --install worker ./infra/helm/worker --namespace app-workload --set image.tag=latest --set image.pullPolicy=Never

echo "🔹 3. Validating Rollout..."
# [cite: 88] Validate rollout status
kubectl rollout status deployment/api -n app-workload
kubectl rollout status deployment/worker -n app-workload

echo "🔹 4. Running Smoke Tests..."
# [cite: 89] Run smoke tests after deployment
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/stats)

if [ "$response" == "200" ]; then
    echo "✅ Smoke Test Passed: API is responding (200 OK)"
else
    echo "❌ Smoke Test Failed: API returned $response"
    exit 1
fi

echo "🚀 Deployment Complete!"