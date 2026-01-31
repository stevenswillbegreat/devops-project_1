# Terraform Infrastructure

## Structure

```
terraform/
├── modules/
│   └── eks-cluster/          # Reusable EKS cluster module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── data.tf
└── environments/
    ├── dev/                  # Development environment
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── terraform.tfvars
    └── prod/                 # Production environment
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars
```

## Usage

### Deploy Development Environment

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### Deploy Production Environment

```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

## Key Differences Between Environments

### Development
- Single NAT Gateway (cost savings)
- Public cluster endpoint
- 2 nodes (t3.medium)
- VPC CIDR: 10.0.0.0/16

### Production
- Multiple NAT Gateways (high availability)
- Private cluster endpoint
- 3 nodes (t3.large)
- VPC CIDR: 10.1.0.0/16

## Customization

Edit the `terraform.tfvars` file in each environment to customize:
- AWS region
- Kubernetes version
- Node sizes and counts
- Network configuration
