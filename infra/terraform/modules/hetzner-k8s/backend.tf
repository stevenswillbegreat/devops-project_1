terraform {
  backend "s3" {
    bucket         = "devops-project-terraform-state"
    key            = "hetzner-k8s/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
  
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}