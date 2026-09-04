terraform {
  required_providers {
    tls = {
      source = "hashicorp/tls"
    }
  }
}terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  backend "s3" {
    region       = "us-west-2"
    bucket       = "tf-playground-ny2mimvtuwdotjwg9ne4yg"
    key          = "kubenutty/linkerd/terraform.tfstate"
    use_lockfile = true
  }
}

provider "aws" {
  allowed_account_ids = ["472882997329"]
  region              = "us-west-2"
}
