terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend "s3" {
  #   bucket = "your-tfstate-bucket"
  #   key    = "your/project/path/terraform.tfstate"
  #   region = "ap-northeast-1"
  # }
}
