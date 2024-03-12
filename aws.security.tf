# ---------------------------------------------------------------------------------------------------------------------
# CREATE KMS KEY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_key" "kmsKey" {
  description              = "KSM Key for project ${var.name}"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  is_enabled               = true
  enable_key_rotation      = true
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD ALIAK FOR KMS KEY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_alias" "kmsKey" {
  name          = "alias/${random_pet.this.id}/${var.kmsAlias}"
  target_key_id = aws_kms_key.kmsKey.key_id
}


# ---------------------------------------------------------------------------------------------------------------------
# GRANT KMS KEY ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_grant" "kmsKey" {
  name              = "grantAccess"
  key_id            = aws_kms_key.kmsKey.key_id
  grantee_principal = aws_iam_role.ecs_task_execution_role.arn
  operations        = ["Encrypt", "Decrypt"]
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE SSM PARAMETER TO STORE DB PWD
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ssm_parameter" "secureVariable" {
  name        = "/${random_pet.this.id}/postgres/grafana/postgres"
  description = "Grafana Postgres DB"
  type        = "SecureString"
  value       = random_string.grafana-db-password.result
  key_id      = aws_kms_key.kmsKey.id
}


# ---------------------------------------------------------------------------------------------------------------------
# ECS ASSUME ROLE
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_task" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE EXECUTION ROLE FOR THE ECS TASK
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name                 = "grafana-task-execution-role"
  assume_role_policy   = data.aws_iam_policy_document.ecs_task.json
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE ECS TASK ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_role" {
  name                 = "grafana-task-role"
  assume_role_policy   = data.aws_iam_policy_document.ecs_task.json
}

# ---------------------------------------------------------------------------------------------------------------------
# CUSTOM POLICY TO ALLOW TO DECRYPT KEY FROM SSM
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "ecs_task_custom_policy" {
  name = "grafana-ecs-task-custom-policy"
  path = "/"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "ssm:GetParameters",
                "secretsmanager:GetSecretValue",
                "kms:Decrypt"
            ],
            "Effect": "Allow",
            "Resource": [
                "${aws_ssm_parameter.secureVariable.arn}"
            ]
        }
    ]
}
EOF
}


# ---------------------------------------------------------------------------------------------------------------------
# ATTACH CUSTOM POLICY 
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "task_custom" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_custom_policy.arn
}


# ---------------------------------------------------------------------------------------------------------------------
# ATTACH CUSTOM POLICY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "task_execution_custom" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_custom_policy.arn
}


# ---------------------------------------------------------------------------------------------------------------------
# Provide CloudWatch Access
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "task_cloudwatch" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}


# ---------------------------------------------------------------------------------------------------------------------
# PROVIDE ATHEN ACCESS, THIS IS USING AMG POLICY BUT YOU CAN USE YOUR OWN  IF YOU WANT
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "task_amg_athena" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonGrafanaAthenaAccess"
}


# ---------------------------------------------------------------------------------------------------------------------
# ADD XRAY ACCESSS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "task_xray" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayReadOnlyAccess"
}


# ---------------------------------------------------------------------------------------------------------------------
# Security Group for ALB
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "grafana-alb-sg"
  description = "Allow traffic to the ALB created for the grafana service"
  vpc_id      = aws_vpc.main.id
 
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    #cidr_blocks = var.whiteListIP

    prefix_list_ids = [aws_ec2_managed_prefix_list.alb_sg_grafana.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# SECURITY GROUP FOR EFS SHARE
# ** EFS NOT WORKING IN THIS SCRIPT **
# ---------------------------------------------------------------------------------------------------------------------

# Security group for the EFS share and mount target
resource "aws_security_group" "efs_sg" {
  name        = "grafana-efs-sg"
  description = "Allow traffic to the EFS storage volume"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [aws_security_group.ecs_service_security_group.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# ALB PREFIX LIST, TO ALLOWLIST IP IF YOU WANT TO RESTRICT ACCESS IN THIS WAY. 
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ec2_managed_prefix_list" "alb_sg_grafana" {
  name           = "alb_sg_grafana"
  address_family = "IPv4"
  max_entries    = 50
}