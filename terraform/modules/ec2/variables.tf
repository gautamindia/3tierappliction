variable "name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "subnet_id" {
  type = string
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "associate_public_ip" {
  type    = bool
  default = true
}

variable "user_data" {
  description = "Rendered user_data script (bootstrap only; ongoing deploys happen via SSM, not re-running this)"
  type        = string
  default     = ""
}

variable "ami_id" {
  description = "AMI to use. Leave null to use the latest Amazon Linux 2023 AMI."
  type        = string
  default     = "ami-0b6d9d3d33ba97d99"
}

variable "key_name" {
  description = "Optional EC2 key pair name for emergency SSH access. Leave null to rely on SSM Session Manager only."
  type        = string
  default     = null
}

variable "extra_tags" {
  description = "Additional tags -- used by the app-deploy pipeline to target instances (e.g. Tier = frontend)"
  type        = map(string)
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
