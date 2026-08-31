############################################
# 1. Three separate VPCs, one per tier
############################################

module "frontend_vpc" {
  source = "../../modules/vpc"

  name                 = "${var.project}-frontend"
  cidr_block           = var.frontend_vpc_cidr
  azs                  = local.azs
  public_subnet_cidrs  = [var.frontend_subnet_cidr]
  tags                 = local.tags
}

module "backend_vpc" {
  source = "../../modules/vpc"

  name                 = "${var.project}-backend"
  cidr_block           = var.backend_vpc_cidr
  azs                  = local.azs
  public_subnet_cidrs  = [var.backend_subnet_cidr]
  tags                 = local.tags
}

module "database_vpc" {
  source = "../../modules/vpc"

  name                  = "${var.project}-database"
  cidr_block            = var.database_vpc_cidr
  azs                   = local.azs
  private_subnet_cidrs  = [var.database_subnet_a_cidr, var.database_subnet_b_cidr]
  tags                  = local.tags
}

############################################
# 2. VPC peering: frontend<->backend, backend<->database.
#    Deliberately NO peering between frontend and database --
#    VPC peering is non-transitive in AWS, so the frontend has
#    no network path to the database tier at all, even though
#    both peer with backend.
############################################

module "frontend_backend_peering" {
  source = "../../modules/peering"

  name           = "${var.project}-frontend-backend"
  requester_vpc_id = module.frontend_vpc.vpc_id
  accepter_vpc_id  = module.backend_vpc.vpc_id
  requester_cidr   = module.frontend_vpc.cidr_block
  accepter_cidr    = module.backend_vpc.cidr_block

  requester_route_table_ids = [module.frontend_vpc.public_route_table_id]
  accepter_route_table_ids  = [module.backend_vpc.public_route_table_id]

  tags = local.tags
}

module "backend_database_peering" {
  source = "../../modules/peering"

  name           = "${var.project}-backend-database"
  requester_vpc_id = module.backend_vpc.vpc_id
  accepter_vpc_id  = module.database_vpc.vpc_id
  requester_cidr   = module.backend_vpc.cidr_block
  accepter_cidr    = module.database_vpc.cidr_block

  requester_route_table_ids = [module.backend_vpc.public_route_table_id]
  accepter_route_table_ids  = [module.database_vpc.private_route_table_id]

  tags = local.tags
}

############################################
# 3. Security groups -- these are the actual enforcement point.
#    Even though frontend has no route to the DB VPC, we also lock
#    down security groups so nothing is reachable that shouldn't be.
############################################

module "frontend_sg" {
  source = "../../modules/security_group"

  name        = "${var.project}-frontend-sg"
  description = "Frontend tier: accepts HTTP from the internet, talks only to backend"
  vpc_id      = module.frontend_vpc.vpc_id

  ingress_rules = [
    {
      description = "HTTP from the internet"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "SSH for admin access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  egress_rules = [
    {
      description = "App traffic to backend tier only"
      from_port   = 5000
      to_port     = 5000
      protocol    = "tcp"
      cidr_blocks = [var.backend_vpc_cidr]
    },
    {
      description = "HTTPS out for OS/package updates"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTP out for OS/package updates"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  tags = local.tags
}

module "backend_sg" {
  source = "../../modules/security_group"

  name        = "${var.project}-backend-sg"
  description = "Backend tier: accepts app traffic from frontend only, talks only to the database"
  vpc_id      = module.backend_vpc.vpc_id

  ingress_rules = [
    {
      description = "App traffic from frontend tier only"
      from_port   = 5000
      to_port     = 5000
      protocol    = "tcp"
      cidr_blocks = [var.frontend_vpc_cidr]
    },
    {
      description = "SSH for admin access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  egress_rules = [
    {
      description = "Postgres to database tier only"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [var.database_vpc_cidr]
    },
    {
      description = "HTTPS out for OS/package updates"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTP out for OS/package updates"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  tags = local.tags
}

module "database_sg" {
  source = "../../modules/security_group"

  name        = "${var.project}-database-sg"
  description = "Database tier: accepts Postgres traffic from backend only"
  vpc_id      = module.database_vpc.vpc_id

  ingress_rules = [
    {
      description = "Postgres from backend tier only"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [var.backend_vpc_cidr]
    }
  ]

  # No egress rules needed/wanted -- RDS never initiates outbound connections.
  egress_rules = []

  tags = local.tags
}

############################################
# 4. RDS database (private subnets, database VPC only)
############################################

module "rds" {
  source = "../../modules/rds"

  identifier              = "${var.project}-db"
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  instance_class          = var.db_instance_class
  subnet_ids              = module.database_vpc.private_subnet_ids
  vpc_security_group_ids  = [module.database_sg.id]

  tags = local.tags
}

############################################
# 5. EC2 instances -- backend first (frontend's bootstrap needs its IP)
############################################

module "backend_ec2" {
  source = "../../modules/ec2"

  name                    = "${var.project}-backend"
  instance_type           = var.instance_type
  subnet_id               = module.backend_vpc.public_subnet_ids[0]
  vpc_security_group_ids  = [module.backend_sg.id]
  associate_public_ip     = true
  key_name                = var.key_name

  

  extra_tags = { Tier = "backend" }
  tags       = local.tags
}

module "frontend_ec2" {
  source = "../../modules/ec2"

  name                    = "${var.project}-frontend"
  instance_type           = var.instance_type
  subnet_id               = module.frontend_vpc.public_subnet_ids[0]
  vpc_security_group_ids  = [module.frontend_sg.id]
  associate_public_ip     = true
  key_name                = var.key_name


  extra_tags = { Tier = "frontend" }
  tags       = local.tags
}
