variable "region" {
}

variable "servers_per_az" {
  default = 1
}

variable "instance_type" {
  default = "t3.nano"
}

variable "blacklisted_az" {
  default = ["eu-west-1a", "us-east-1c", "eu-central-1a"]
}