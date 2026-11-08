# Golang App: AWS Infrastructure & Deployment

Terraform provisions a secure AWS environment, and Docker Compose runs the Go backend and MongoDB. Backend instances sit in private subnets and receive traffic only through an Application Load Balancer (ALB).

## Architecture

- **VPC** `10.0.0.0/16` with 2 public and 2 private subnets across 2 AZs
- **Internet Gateway** for public subnets; **2 NAT Gateways** (one per AZ) for private outbound traffic
- **ALB** (internet-facing) forwarding to healthy backends, health check on `/health`
- **Bastion Host** with an Elastic IP, the only SSH entry point to private instances
- **2 Backend EC2 instances** (Amazon Linux 2) running Docker; user data installs Docker and Docker Compose
- **MongoDB** in one private subnet, reachable only from the backend security group

### Security groups

| Group   | Inbound                                       |
| ------- | --------------------------------------------- |
| ALB     | 80, 443 from `0.0.0.0/0`                      |
| Bastion | 22 from your public IP                        |
| Backend | 8080 from ALB SG; 22 from Bastion SG          |
| MongoDB | 27017 from Backend SG                         |

> **Note:** Port 443 is open, but no HTTPS listener or TLS certificate is configured yet. Add an ACM certificate and an HTTPS listener to serve HTTPS.

## Prerequisites

AWS account and CLI (configured), Terraform, Git, Docker, Docker Compose, a Docker Hub account, an existing EC2 key pair, and the Go application repo.

## 1. Provision Infrastructure

```bash
git clone REPOSITORY_URL
cd backend-deployment-assessment/terraform
cp terraform.tfvars.example terraform.tfvars   # set region, instance type, your IP, key pair name
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform output alb_dns_name
terraform output bastion_public_ip
```

## 2. Build and Push the Image

The Dockerfile is a multi-stage build (Go builder, Alpine runtime) that runs as a non-root user, exposes `8080`, and includes a `/health` HEALTHCHECK.

```bash
docker build -t much-to-do-backend:v1 .
docker login -u DOCKERHUB_USERNAME
docker tag much-to-do-backend:v1 DOCKERHUB_USERNAME/much-to-do-backend:v1
docker push DOCKERHUB_USERNAME/much-to-do-backend:v1
```

## 3. Deploy to a Backend Instance

Connect through the Bastion:

```bash
ssh -i key.pem -o ProxyCommand="ssh -i key.pem -W %h:%p ec2-user@BASTION_PUBLIC_IP" ec2-user@BACKEND_PRIVATE_IP
```

On the instance, create `docker-compose.yml` and `.env` (see `.env.example` for required variables; never commit real credentials), then:

```bash
docker pull DOCKERHUB_USERNAME/much-to-do-backend:v1
docker compose up -d
docker compose ps
docker compose logs --tail=50 backend
```

Compose runs the backend and MongoDB 7.0 on a bridge network (`app-network`). MongoDB uses a named volume for persistence, has a health check, and is not published to the host. The backend starts only after MongoDB is healthy.

## 4. Verify

```bash
curl -v http://localhost:8080/health          # on the EC2 instance
curl -v http://YOUR_ALB_DNS_NAME/health       # through the ALB
```

Also confirm targets show **healthy** in AWS Console > EC2 > Target Groups.

## Terraform State

```bash
terraform state list
terraform show
```

State can contain secrets. Keep it out of version control and prefer a remote backend with encryption.

## Teardown

```bash
cd terraform
terraform destroy
```