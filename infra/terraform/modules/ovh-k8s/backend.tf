terraform {
  backend "s3" {
    bucket         = "devops-project-terraform-state"
    key            = "ovh-k8s/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
  
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 0.45"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}