variable "name" {
  type        = string
  description = "The name of the task definition"
}

variable "task_role_name" {
  type        = string
  description = "The name of the IAM role for the ECS task"
}

variable "labelstudio_version" {
  type        = string
  description = "The labelstudio version to use"
  default     = "1.3.0"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_host" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "secret_arn" {
  type = string
}

variable "host" {
  type = string
}

variable "efs_id" {
  type = string
}
