variable "identifier" {
  type = string
}

variable "engine" {
  type    = string
  default = "postgres"
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type = string
}

variable "username" {
  type = string
}

variable "password" {
  description = "Master password. Pass via TF_VAR_db_password / a GitHub Actions secret -- never commit it."
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "At least two subnet IDs in different AZs for the DB subnet group"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "backup_retention_period" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
