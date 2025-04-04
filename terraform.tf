provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_ecs_cluster" "medusa_cluster" {
  name = "medusa-cluster"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = "medusa-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-1a", "ap-northeast-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
}

resource "aws_security_group" "ecs_sg" {
  name        = "ecs-security-group"
  description = "Allow inbound traffic for Medusa"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecr_repository" "medusa_repo" {
  name = "medusa-backend"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]
}

resource "aws_ecs_task_definition" "medusa_task" {
  family                   = "medusa-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  memory                   = "512"
  cpu                      = "256"

  container_definitions = jsonencode([{
    name  = "medusa-container"
    image = "${aws_ecr_repository.medusa_repo.repository_url}:latest"
    memory = 512
    cpu    = 256
    essential = true
    portMappings = [{
      containerPort = 9000
      hostPort      = 9000
    }]
    environment = [
      { name = "DATABASE_URL", value = "postgres://medusa_user:medusa_pass@${aws_db_instance.medusa_db.address}/medusa" },
      { name = "REDIS_URL", value = "redis://redis_
