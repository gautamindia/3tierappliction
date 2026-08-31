variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "threetier"
}



# --- VPC / subnet CIDRs ---
variable "frontend_vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "frontend_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "backend_vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "backend_subnet_cidr" {
  type    = string
  default = "10.1.1.0/24"
}

variable "database_vpc_cidr" {
  type    = string
  default = "10.2.0.0/16"
}

variable "database_subnet_a_cidr" {
  type    = string
  default = "10.2.1.0/24"
}

variable "database_subnet_b_cidr" {
  type    = string
  default = "10.2.2.0/24"
}

# --- EC2 ---
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  description = "Optional EC2 key pair for emergency SSH access"
  type        = string
  default     = null
}

# --- App source ---
variable "repo_url" {
  description = "Git URL the instances clone to bootstrap the app on first boot"
  type        = string
}

variable "repo_ref" {
  type    = string
  default = "main"
}

variable "flask_secret_key" {
  type      = string
  sensitive = true
  default   = "change-me"
}

# --- Database ---
variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

variable "db_password" {
  description = "RDS master password. Supply via TF_VAR_db_password or a CI secret -- never commit a real value."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
