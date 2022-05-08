provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state             = "available"
  blacklisted_names = var.blacklisted_az
}

resource "aws_vpc" "main" {
  cidr_block                       = "10.1.0.0/22"
  assign_generated_ipv6_cidr_block = "true"
  enable_dns_support               = "true"
  enable_dns_hostnames             = "true"

  tags = {
    Name = "qa-${var.region}"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "qa-${var.region}-igw"
  }
}

resource "aws_subnet" "public" {
  count                           = length(data.aws_availability_zones.available.names)
  vpc_id                          = aws_vpc.main.id
  cidr_block                      = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index)
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
  availability_zone               = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "qa-${element(data.aws_availability_zones.available.names, count.index)}-public"
  }
}

resource "aws_subnet" "private" {
  vpc_id                          = aws_vpc.main.id
  count                           = length(data.aws_availability_zones.available.names)
  cidr_block                      = "${element(var.private_subnets_cidr, count.index)}"
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
  availability_zone               = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name        = "qa-${element(data.aws_availability_zones.available.names, count.index)}-private"
  }
}

resource "aws_route_table" "public" {
  count  = length(data.aws_availability_zones.available.names)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.default.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = element(aws_route_table.public.*.id, count.index)
}

resource "aws_security_group" "default" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = -1
    to_port          = -1
    protocol         = "icmpv6"
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "server" {
  count                  = length(data.aws_availability_zones.available.names) * var.servers_per_az
  instance_type          = var.instance_type
  ami                    = ami-063a9ea2ff5685f7f
  subnet_id              = element(aws_subnet.public.*.id, count.index)
  ipv6_address_count     = "1"
  vpc_security_group_ids = [aws_security_group.default.id, aws_vpc.main.default_security_group_id]

  credit_specification {
    cpu_credits = "standard"
  }
   user_data = <<-EOF
                    #!/bin/bash
                    sudo yum update -y
                    sudo yum install nginx -y 
                    sudo service start nginx
                EOF

  tags = {
    Name = "qa-server-${element(data.aws_availability_zones.available.names, count.index)}-${count.index}"
  }
}