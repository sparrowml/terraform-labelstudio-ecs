variable "vpc_id" {
  type = string
}

variable "task_role_name" {
  type = string
}

variable "acm_certificate_arn" {
  type = string
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "host" {
  type    = string
  default = ""
}
