# -----------
# VARIABLES
# -----------

variable "aws_region" {
  description = "AWS region to deploy app resources into"
  type        = string
  default     = "us-east-1" # Validate region and AZ
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "project_name" {
  description = "Prefix used for naming resources"
  type        = string
  default     = "startuptech"
}

variable "public_subnet_cidrs" {
  description = "CIDR block for the Public Subnet (One per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs are required."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR block for the private subnet (One per AZ)"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]

  validation {
    condition = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly two private subnet CIDRs are required."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "my_ip" {
  description = "Device public IP"
  type        = string
}

variable "key_pair_name" {
  description = "Name of EC2 key pair"
  type        = string
}
