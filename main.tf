terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

locals {
  name                = "labelstudio"
  labelstudio_version = "1.3.0"
}

module "alb_security_group" {
  source = "../terraform-aws-sparrow/modules/security-group"

  name   = "${local.name}-alb"
  vpc_id = var.vpc_id
  ingress = [
    {
      port        = 80
      all_traffic = true
    },
    {
      port        = 443
      all_traffic = true
    },
  ]
  all_egress = true
}

module "ec2_security_group" {
  source = "../terraform-aws-sparrow/modules/security-group"

  name   = "${local.name}-ec2"
  vpc_id = var.vpc_id
  ingress = [
    {
      port              = 80
      security_group_id = module.alb_security_group.id
      my_ip             = true
    },
  ]
  all_egress = true
}

module "rds_security_group" {
  source = "../terraform-aws-sparrow/modules/security-group"

  name   = "${local.name}-rds"
  vpc_id = var.vpc_id
  ingress = [
    {
      port              = 5432
      security_group_id = module.ec2_security_group.id
    },
  ]
}

module "rds_instance" {
  source             = "../terraform-aws-sparrow/modules/rds-instance"
  name               = local.name
  engine             = "postgres"
  instance_type      = "db.t4g.micro"
  vpc_id             = var.vpc_id
  security_group_ids = [module.rds_security_group.id]
  public             = false
  auth = {
    username = var.db_username
    password = var.db_password
  }
}

resource "aws_ecs_cluster" "app_cluster" {
  name = local.name
}

data "aws_caller_identity" "current" {}

resource "aws_ecs_task_definition" "labelstudio" {
  family             = "service"
  execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.execution_role_name}"
  container_definitions = jsonencode([
    {
      name      = local.name
      image     = "heartexlabs/label-studio:${local.labelstudio_version}"
      cpu       = 1024
      memory    = 512
      essential = true
      environment = [
        {
          name  = "DJANGO_DB"
          value = "default"
        },
        {
          name  = "POSTGRE_NAME"
          value = "postgres"
        },
        {
          name  = "POSTGRE_USER"
          value = var.db_username
        },
        {
          name  = "POSTGRE_PASSWORD"
          value = var.db_password
        },
        {
          name  = "POSTGRE_PORT"
          value = "5432"
        },
        {
          name  = "POSTGRE_HOST"
          value = module.rds_instance.dns
        },
      ]
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 80
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "labelstudio" {
  name                               = local.name
  cluster                            = aws_ecs_cluster.app_cluster.id
  task_definition                    = aws_ecs_task_definition.labelstudio.arn
  desired_count                      = 1
  force_new_deployment               = true
  deployment_minimum_healthy_percent = 0
}

module "ec2_instance" {
  source = "../terraform-aws-sparrow/modules/ec2-instance"
  count  = 1

  name               = "${local.name}-${count.index}"
  ecs_cluster_name   = local.name
  instance_type      = "t3.micro"
  vpc_id             = var.vpc_id
  security_group_ids = [module.ec2_security_group.id]
  iam_role           = "ecsInstanceRole"
}
