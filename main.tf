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
  log_group_name      = "/ecs/labelstudio"
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

resource "aws_cloudwatch_log_group" "logs" {
  name = local.log_group_name
}

module "secret" {
  source = "../terraform-aws-sparrow/modules/secret"

  name  = "${local.name}-db-password"
  value = var.db_password
}

module "ecs_task_definition" {
  source = "./task-definition"

  name                = local.name
  task_role_name      = var.task_role_name
  labelstudio_version = local.labelstudio_version
  db_host             = module.rds_instance.dns
  db_username         = var.db_username
  host                = var.host
  secret_arn          = module.secret.arn
  log_group_name      = local.log_group_name
}

resource "aws_ecs_service" "labelstudio" {
  name                               = local.name
  cluster                            = aws_ecs_cluster.app_cluster.id
  task_definition                    = module.ecs_task_definition.arn
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

module "alb" {
  source              = "../terraform-aws-sparrow/modules/alb"
  name                = local.name
  vpc_id              = var.vpc_id
  security_group_ids  = [module.alb_security_group.id]
  instance_ids        = [for i in module.ec2_instance : i.id]
  acm_certificate_arn = var.acm_certificate_arn
}

output "host" {
  value = module.alb.dns
}
