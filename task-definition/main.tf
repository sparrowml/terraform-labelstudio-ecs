data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_ecs_task_definition" "labelstudio" {
  family                = "service"
  execution_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.task_role_name}"
  container_definitions = <<EOT
    [{
        "name" : "${var.name}",
        "image" : "heartexlabs/label-studio:${var.labelstudio_version}",
        "cpu" : 1024,
        "memory" : 768,
        "essential" : true,
        "environment" : [{
        "name" : "DJANGO_DB",
        "value" : "default"
        },
        {
            "name" : "POSTGRE_NAME",
            "value" : "postgres"
        },
        {
            "name" : "POSTGRE_USER",
            "value" : "${var.db_username}"
        },
        {
            "name" : "POSTGRE_PASSWORD",
            "value" : "${var.db_password}"
        },
        {
            "name" : "POSTGRE_PORT",
            "value" : "5432"
        },
        {
            "name" : "POSTGRE_HOST",
            "value" : "${var.db_host}"
        }
        ],
        "portMappings" : [{
            "containerPort" : 8080,
            "hostPort" : 80
        }],
        "logConfiguration" : {
        "logDriver" : "awslogs",
            "options" : {
                "awslogs-region" : "${data.aws_region.current.name}",
                "awslogs-group" : "${var.log_group_name}"
            }
        }
    }]
  EOT
}
