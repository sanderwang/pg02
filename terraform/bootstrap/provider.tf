terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  backend "kubernetes" {
    config_path    = "~/.kube/config"
    config_context = "arn:aws:eks:us-west-2:472882997329:cluster/eks-playground"
    namespace      = "default"
    secret_suffix  = "pg02-kubenuts-bootstrap"
  }
}

provider "aws" {
  allowed_account_ids = ["472882997329"]
  region              = "us-west-2"
}
