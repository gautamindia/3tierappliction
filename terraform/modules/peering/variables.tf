variable "name" {
  description = "Name for the peering connection"
  type        = string
}

variable "requester_vpc_id" {
  type = string
}

variable "accepter_vpc_id" {
  type = string
}

variable "requester_cidr" {
  description = "CIDR of the requester VPC (used for the route added on the accepter side)"
  type        = string
}

variable "accepter_cidr" {
  description = "CIDR of the accepter VPC (used for the route added on the requester side)"
  type        = string
}

variable "requester_route_table_ids" {
  description = "Route table IDs on the requester side that need a route to the accepter VPC"
  type        = list(string)
  default     = []
}

variable "accepter_route_table_ids" {
  description = "Route table IDs on the accepter side that need a route to the requester VPC"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
