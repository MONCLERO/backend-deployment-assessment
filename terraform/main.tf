# ---------------
# TERRAFORM INIT
# ---------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Version constraint/limit
    }
  }
}

provider "aws" {
  region = var.aws_region
}


# -------------------
# AVAILABILITY ZONE
# -------------------

data "aws_availability_zones" "available" {
  state = "available"
}


# -----------
# NETWORKING 
# -----------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# -- PUBLIC SUBNET -- #

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
  }
}

resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_route.id
}

# -- PRIVATE SUBNET -- #

resource "aws_eip" "nat" {
  count = 2

  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "nat" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw, aws_route_table_association.public]
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"
  }
}

resource "aws_route_table" "private_route" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_route[count.index].id
}


# ----------------
# SECURITY GROUPS
# ----------------

# -- Backend SG -- #

resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Allow HTTP from ALB & SSH from IP"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-backend-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend-http" {
  security_group_id            = aws_security_group.backend.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  ip_protocol                  = "tcp"
  to_port                      = 8080
}

resource "aws_vpc_security_group_ingress_rule" "backend-ssh" {
  security_group_id            = aws_security_group.backend.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "backend_all_outbound" {
  security_group_id = aws_security_group.backend.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# -- Bastion SG -- #

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH from personal IP"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion-ssh" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "${var.my_ip}/32"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "bastion_all_outbound" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# -- ALB SG -- #

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP from the Internet to the Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_all_outbound" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports & all protocols
}

# -- MONGODB SG -- #

resource "aws_security_group" "mongodb" {
  name        = "${var.project_name}-mongodb-sg"
  description = "Allow 27017 from Backend only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-mongodb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "mongo_allow_backend" {
  security_group_id            = aws_security_group.mongodb.id
  referenced_security_group_id = aws_security_group.backend.id
  from_port                    = 27017
  ip_protocol                  = "tcp"
  to_port                      = 27017
}


# ----------------------------------
# EC2 INSTANCES [AMI --> INSTANCES]
# ----------------------------------

# -- AMI LOOKUP -- #

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name = "architecture"
    values = ["x86_64"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

# -- INSTANCES -- #

resource "aws_instance" "bastion-host" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = var.key_pair_name

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

resource "aws_instance" "backend-server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.backend.id]
  key_name               = var.key_pair_name
  depends_on             = [aws_route_table_association.private]

  user_data = templatefile(
    "${path.module}/user_data/backend_setup.sh",
    {}
  )
  user_data_replace_on_change = true

  count = 2
  tags = {
    Name = "${var.project_name}-backend-${count.index + 1}"
  }
}

resource "aws_instance" "mongodb-server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.mongodb.id]
  key_name               = var.key_pair_name
  depends_on             = [aws_route_table_association.private]

  user_data = templatefile(
    "${path.module}/user_data/mongodb_setup.sh",
    {}
  )
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-mongodb-1"
  }
}


# ---------------------------
# APPLICATION LOAD BALANCER
# ---------------------------

resource "aws_lb" "main" {
  name               = "${var.project_name}-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = false

  tags = {
    Environment = "dev"
  }
}

# -- TARGET GROUP -- #

resource "aws_lb_target_group" "alb_tg" {
  name     = "${var.project_name}-lb-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled = true
    path    = "/health"
  }
}

# -- ALB TARGET GROUP ATTACHMENT -- #

resource "aws_lb_target_group_attachment" "tg_attachment" {
  count = length(aws_instance.backend-server)

  target_group_arn = aws_lb_target_group.alb_tg.arn
  target_id        = aws_instance.backend-server[count.index].id
}

# -- ALB LISTENER - REQUESTS ON PORT 80 -- #

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}
