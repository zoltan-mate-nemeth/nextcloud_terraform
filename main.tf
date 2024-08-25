provider "aws" {
  region  = var.aws_region
  profile = "your_aws_profile_name" # Replace with your AWS CLI profile name
}

# Create a VPC
resource "aws_vpc" "nextcloud_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "NextcloudVPC" }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "nextcloud_igw" {
  vpc_id = aws_vpc.nextcloud_vpc.id
  tags   = { Name = "NextcloudIGW" }
}

# Create a Subnet
resource "aws_subnet" "nextcloud_subnet" {
  vpc_id                  = aws_vpc.nextcloud_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  tags                    = { Name = "NextcloudSubnet" }
}

# Create a Route Table
resource "aws_route_table" "nextcloud_route_table" {
  vpc_id = aws_vpc.nextcloud_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nextcloud_igw.id
  }
  tags = { Name = "NextcloudRouteTable" }
}

# Associate the Route Table with the Subnet
resource "aws_route_table_association" "nextcloud_route_table_assoc" {
  subnet_id      = aws_subnet.nextcloud_subnet.id
  route_table_id = aws_route_table.nextcloud_route_table.id
}

# Create a Security Group
resource "aws_security_group" "nextcloud_sg" {
  name        = "NextcloudSG"
  description = "Security group for Nextcloud"
  vpc_id      = aws_vpc.nextcloud_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "NextcloudSG" }
}

# Launch an EC2 Instance
resource "aws_instance" "nextcloud_instance" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.nextcloud_key.key_name
  vpc_security_group_ids = [aws_security_group.nextcloud_sg.id]
  subnet_id              = aws_subnet.nextcloud_subnet.id

  user_data = templatefile("${path.module}/user_data.tpl", {
    domain_name         = var.domain_name
    subdomain           = var.subdomain
    email               = var.email
    mysql_root_password = var.mysql_root_password
    mysql_password      = var.mysql_password
    nextcloud_version   = var.nextcloud_version
  })

  tags = { Name = "NextcloudInstance" }
}

# Create an Elastic IP
resource "aws_eip" "nextcloud_eip" {
  domain = "vpc"
  tags = {
    Name = "NextcloudEIP"
  }
}

# Associate the Elastic IP with the EC2 instance
resource "aws_eip_association" "nextcloud_eip_assoc" {
  instance_id   = aws_instance.nextcloud_instance.id
  allocation_id = aws_eip.nextcloud_eip.id
}

# Create aws_key_pair
resource "aws_key_pair" "nextcloud_key" {
  key_name   = "nextcloud-key"
  public_key = file(var.public_key_path)
}

# Query the Route53 DNS zone
data "aws_route53_zone" "selected" {
  name = var.domain_name
}

# Create a DNS A record
resource "aws_route53_record" "nextcloud_dns" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.nextcloud_eip.public_ip]
}

# Outputs
output "nextcloud_url" {
  value       = "https://${var.subdomain}.${var.domain_name}"
  description = "The URL of the Nextcloud instance"
}

output "instance_public_ip" {
  value       = aws_eip.nextcloud_eip.public_ip
  description = "The public IP of the EC2 instance"
}
