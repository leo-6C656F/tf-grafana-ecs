# ---------------------------------------------------------------------------------------------------------------------
# RANDOM 32 CHARACTER STRING FOR DATABASE PASSWORD
# ---------------------------------------------------------------------------------------------------------------------
resource "random_string" "grafana-db-password" {
  length  = 32
  upper   = true
  special = true
}


# ---------------------------------------------------------------------------------------------------------------------
#S ECURTY GROUP - ALLOW INBOUD ACCESS TO DATABASE, ALLOW INBOUD ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "grafana-db-sg" {
  vpc_id      = aws_vpc.main.id
  name        = "grafana-rds-access"
  description = "Allow all inbound for Postgres"
ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    security_groups = [aws_security_group.ecs_service_security_group.id]
  }
egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# SUBNET - DATABASE SUBNET GROUP
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_db_subnet_group" "db_subnets" {
  name       = "main"
  subnet_ids = concat(aws_subnet.private_subnets.*.id,aws_subnet.public_subnets.*.id)

  tags = {
    Name = "Database subnet group"
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# DATABASE - POSTGRES DATABASE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_db_instance" "grafana-db" {
  identifier             = "grafana-db"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "15.5"
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name

  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.grafana-db-sg.id]
  username               = "grafana"
  password               = random_string.grafana-db-password.result
}