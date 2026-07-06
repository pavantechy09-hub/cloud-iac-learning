module "vpc" {
  source = "../../modules/vpc"

  environment         = "staging"
  vpc_cidr            = "10.1.0.0/16"
  public_subnet_cidr  = "10.1.1.0/24"
  private_subnet_cidr = "10.1.2.0/24"
  data_subnet_cidr    = "10.1.3.0/24"
  az                  = "us-east-1a"
}