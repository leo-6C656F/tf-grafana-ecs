# ---------------------------------------------------------------------------------------------------------------------
# PRIMARY VPC
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_vpc" "main" {
 cidr_block = "10.0.0.0/16"
}


# ---------------------------------------------------------------------------------------------------------------------
# PUBLIC SUBNETS FOR THE VPC
# ---------------------------------------------------------------------------------------------------------------------
variable "public_subnet_cidrs" {
 type        = list(string)
 description = "Public Subnet CIDR values"
 default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
 

# ---------------------------------------------------------------------------------------------------------------------
# PRIVATE SUBNETS FOR THE VPC
# ---------------------------------------------------------------------------------------------------------------------
variable "private_subnet_cidrs" {
 type        = list(string)
 description = "Private Subnet CIDR values"
 default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}


# ---------------------------------------------------------------------------------------------------------------------
#  AVAILABILITY ZONE
# ---------------------------------------------------------------------------------------------------------------------
variable "azs" {
 type        = list(string)
 description = "Availability Zones"
 default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}


# ---------------------------------------------------------------------------------------------------------------------
# ATTACH PUBLIC SUBNET
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_subnet" "public_subnets" {
 count      = length(var.public_subnet_cidrs)
 vpc_id     = aws_vpc.main.id
 cidr_block = element(var.public_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 
 
 tags = {
   Name = "Public Subnet ${count.index + 1}"
 }
}


# ---------------------------------------------------------------------------------------------------------------------
# ATTACH PRIVATE SUBNET
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_subnet" "private_subnets" {
 count      = length(var.private_subnet_cidrs)
 vpc_id     = aws_vpc.main.id
 cidr_block = element(var.private_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 
 
 tags = {
   Name = "Private Subnet ${count.index + 1}"
 }
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
 vpc_id = aws_vpc.main.id
 
 tags = {
   Name = "Project VPC IG"
 }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREEATE ROUTE TABLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_route_table" "second_rt" {
 vpc_id = aws_vpc.main.id
 
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.gw.id
 }
 
 tags = {
   Name = "2nd Route Table"
 }
}


# ---------------------------------------------------------------------------------------------------------------------
# ASSOCIATE ROUTING TABLE TO PUBLIC SUBNET
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_route_table_association" "public_subnet_asso" {
 count = length(var.public_subnet_cidrs)
 subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
 route_table_id = aws_route_table.second_rt.id
}


# ---------------------------------------------------------------------------------------------------------------------
#  CREATE THE LB TARGET GROUP TO WHICH THE SERVICE ABOVE WILL ATTACH
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb_target_group" "target_group" {
  name                  = "grafana-target-group"
  port                  = 80
  protocol              = "HTTP"
  target_type           = "ip"
  vpc_id                = aws_vpc.main.id
}


# ---------------------------------------------------------------------------------------------------------------------
#  CREATE THE APPLICATION LOAD BALANCER FOR THE ECS SERVICE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb" "ecs_alb" {
  name                              = "grafana-alb"
  internal                          = false
  load_balancer_type                = "application"
  security_groups                   = ["${aws_security_group.alb_sg.id}"]
  subnets                           = aws_subnet.public_subnets.*.id
  enable_cross_zone_load_balancing  = true
  enable_http2                      = true
}


# ---------------------------------------------------------------------------------------------------------------------
#  CREATE HTTP LISTENER
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
#  CREATE AN ACM CERTIFICATE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_acm_certificate" "ssl_certificate" {
  domain_name       = "example.com"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
#  CREATE HTTPS LISTENER
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.ssl_certificate.id

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}