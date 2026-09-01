

resource "aws_instance" "this" {
  ami                         = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux[0].id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.vpc_security_group_ids
  associate_public_ip_address = var.associate_public_ip
  
  key_name                    = var.key_name
  user_data                   = var.user_data

  metadata_options {
    http_tokens = "required" # require IMDSv2
  }

  tags = merge(var.tags, var.extra_tags, { Name = var.name })
}
