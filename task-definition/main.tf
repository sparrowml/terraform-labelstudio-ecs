data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_ecs_task_definition" "labelstudio" {
  family             = "service"
  execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.task_role_name}"

  volume {
    name = "efs"
    efs_volume_configuration {
      file_system_id = var.efs_id
    }
  }

  container_definitions = <<EOT
    [{
        "name" : "${var.name}",
        "image" : "heartexlabs/label-studio:${var.labelstudio_version}",
        "cpu" : 2048,
        "memory" : 1954,
        "essential" : true,
        "mountPoints": [
            {
                "containerPath": "/label-studio",
                "sourceVolume": "efs"
            }
        ],
        "environment" : [
            {
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
                "name" : "POSTGRE_PORT",
                "value" : "5432"
            },
            {
                "name" : "POSTGRE_HOST",
                "value" : "${var.db_host}"
            },
            {
                "name" : "LABEL_STUDIO_HOST",
                "value" : "${var.host}"
            },
            {
                "name": "LABEL_STUDIO_COPY_STATIC_DATA",
                "value": "true"
            },
            {
                "name": "LABEL_STUDIO_DISABLE_SIGNUP_WITHOUT_LINK",
                "value": "true"
            }
        ],
        "secrets": [
            {
                "name": "POSTGRE_PASSWORD",
                "valueFrom": "${var.secret_arn}"
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
