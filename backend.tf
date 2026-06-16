terraform {
  backend "s3" {
    bucket       = "richkode-tf-state-bucket"
    key          = "dev/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}