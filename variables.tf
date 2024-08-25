variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "subnet_cidr" {
  description = "The CIDR block for the subnet"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "The instance type for the EC2 instance"
  type        = string
}

variable "public_key_path" {
  description = "The path to the public key for SSH access"
  type        = string
}

variable "domain_name" {
  description = "The main domain name"
  type        = string
}

variable "subdomain" {
  description = "The subdomain for the Nextcloud instance"
  type        = string
}

variable "email" {
  description = "The email address for SSL certificate"
  type        = string
}

variable "mysql_root_password" {
  description = "The root password for MySQL"
  type        = string
}

variable "mysql_password" {
  description = "The password for the Nextcloud MySQL user"
  type        = string
}

variable "nextcloud_version" {
  description = "The version of Nextcloud to install"
  type        = string
}
