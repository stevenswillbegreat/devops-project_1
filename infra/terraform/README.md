# Terraform Backend Configuration

This project uses S3 backend for Terraform state management with DynamoDB for state locking.

## Backend Structure

```
S3 Bucket: devops-project-terraform-state
├── aws-eks/terraform.tfstate          # AWS EKS cluster state
├── hetzner-k8s/terraform.tfstate      # Hetzner Cloud cluster state
└── ovh-k8s/terraform.tfstate          # OVH Public Cloud cluster state

DynamoDB Table: terraform-state-lock    # State locking
```

## Setup

1. **Create Backend Infrastructure** (one-time setup):
   ```bash
   ./scripts/setup-terraform-backend.sh
   ```

2. **Initialize Each Module**:
   ```bash
   # AWS EKS
   cd infra/terraform
   terraform init

   # Hetzner Cloud
   cd modules/hetzner-k8s
   terraform init

   # OVH Public Cloud
   cd modules/ovh-k8s
   terraform init
   ```

## Benefits

- **State Isolation**: Each cloud provider has separate state files
- **Concurrent Operations**: Multiple team members can work simultaneously
- **State Locking**: Prevents concurrent modifications
- **Versioning**: S3 versioning enables state recovery
- **Encryption**: State files encrypted at rest

## Requirements

- AWS CLI configured with appropriate permissions
- S3 bucket creation permissions
- DynamoDB table creation permissions