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

variable "instance_count" {
  type    = number
  default = 2
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}
