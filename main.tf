terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

locals {
  name   = "labelstudio"
  vpc_id = "vpc-0f5278a21331f0540"
}

module "alb_security_group" {
  source = "../terraform-aws-sparrow/modules/security-group"

  name   = "${local.name}-alb"
  vpc_id = local.vpc_id
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
  vpc_id = local.vpc_id
  ingress = [
    {
      port              = 8080
      security_group_id = module.alb_security_group.id
    },
  ]
  all_egress = true
}

module "rds_security_group" {
  source = "../terraform-aws-sparrow/modules/security-group"

  name   = "${local.name}-rds"
  vpc_id = local.vpc_id
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
  vpc_id             = local.vpc_id
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

module "ec2_instance" {
  source = "../terraform-aws-sparrow/modules/ec2-instance"
  count  = 1

  name               = "${local.name}-${count.index}"
  ecs_cluster_name   = local.name
  instance_type      = "t3.micro"
  vpc_id             = local.vpc_id
  security_group_ids = [module.ec2_security_group.id]
  iam_role           = "ecsInstanceRole"
}
