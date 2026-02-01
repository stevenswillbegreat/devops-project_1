terraform {
  backend "s3" {
    bucket         = "devops-project-terraform-state"
    key            = "aws-eks/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}