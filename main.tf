module "qa-us-east-2" {
  source        = "./qa"
  region        = "us-east-1"
  instance_type = "t3.micro"
}

module "qa-eu-west-1" {
  source = "./qa"
  region = "eu-west-1"

module "qa-eu-central-1" {
  source = "./qa"
  region = "eu-central-1"
}