variable "name" {
  description = "Name prefix for the VPC and its resources"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones to use, indexed against the subnet CIDR lists"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (get an IGW route + auto-assigned public IPs). Leave empty for a fully private VPC (e.g. the database tier)."
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (no route to an Internet Gateway)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
