# Same-account, same-region peering connection. auto_accept works because
# both VPCs live in the same account/region in this setup.
resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.requester_vpc_id
  peer_vpc_id = var.accepter_vpc_id
  auto_accept = true

  tags = merge(var.tags, { Name = var.name })
}

# Route from the requester's route table(s) to the accepter VPC's CIDR
resource "aws_route" "requester_to_accepter" {
  count                     = length(var.requester_route_table_ids)
  route_table_id             = var.requester_route_table_ids[count.index]
  destination_cidr_block     = var.accepter_cidr
  vpc_peering_connection_id  = aws_vpc_peering_connection.this.id
}

# Route from the accepter's route table(s) back to the requester VPC's CIDR
resource "aws_route" "accepter_to_requester" {
  count                     = length(var.accepter_route_table_ids)
  route_table_id             = var.accepter_route_table_ids[count.index]
  destination_cidr_block     = var.requester_cidr
  vpc_peering_connection_id  = aws_vpc_peering_connection.this.id
}
