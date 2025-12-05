variable "aws_region" {
  default = "us-east-2"
}

variable "github_repo_owner" {
  type    = string
  default = "krishu097"
}

variable "github_repo" {
  type    = string
  default = "MLOPS-POC"
}

variable "training_data_bucket" {
  type    = string
  default = "poc-mlops-bucket-gmk"
}

variable "training_data_prefix" {
  type    = string
  default = "training-data/"
}