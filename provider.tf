terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.11.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.4.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
  }

  backend "s3" {
    bucket         = "project-state-s3bucket"
    key            = "project-2026-root/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.region
}

provider "vault" {}
