# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ELASTIC FILE SYSTEM (NFS) TO PROVIDE PERMANENT STORAGE FOR GRAFANA 
# *** NOT WORKING AT THE MOMENT ***
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_efs_file_system" "ecs_service_storage" {
  tags = {
    Name = "grafana-efs"
  }
}

resource "aws_efs_mount_target" "ecs_service_storage" {
  count           = length(aws_subnet.private_subnets)

  file_system_id  = aws_efs_file_system.ecs_service_storage.id
  subnet_id       = aws_subnet.private_subnets[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}


resource "aws_efs_access_point" "ecs_service_access_point" {
	file_system_id = aws_efs_file_system.ecs_service_storage.id
	posix_user {
		gid = 472
		uid = 472
	}
	root_directory {
		creation_info {
		  owner_gid   = 472
		  owner_uid   = 472
		  permissions = 755
		}
		path = "/grafana"
	}

}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ECS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ecs_cluster" "grafana_cluster" {
  name = "grafana-cluster"
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE ECS TASK DEFINITION
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "grafana" {
	family                   = "Grafana"
	requires_compatibilities = ["FARGATE"]
	network_mode             = "awsvpc"
	cpu                      = 1024
	memory                   = 2048
	runtime_platform {
	operating_system_family = "LINUX"
	cpu_architecture = "ARM64"
	}

	task_role_arn             = aws_iam_role.ecs_task_role.arn
	execution_role_arn        = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
		name      = "Grafana"
		image     = "grafana/grafana-enterprise:10.4.0"
		cpu       = 1024
		memory    = 2048
		essential = true

		volumesFrom  = []
		portMappings = [
			{
			  containerPort = 3000
			  hostPort		= 3000
			  protocol      = "tcp"
			},
		],
		# ---------------------------------------------------------------------------------------------------------------------
		# SECRETE ENVIRONMENT VARIABLES THAT ARE STORED IN SSM, THIS IS WHERE THE DB PWD IS STORED AND ENTERED
		# ---------------------------------------------------------------------------------------------------------------------
		secrets = [
			{
				name = "GF_DATABASE_PASSWORD",
				valueFrom = "${aws_ssm_parameter.secureVariable.arn}"
			}
		],
		# ---------------------------------------------------------------------------------------------------------------------
		# GRAFANA ENVIRONMENT VARIABLES 
		# ---------------------------------------------------------------------------------------------------------------------
		environment = [
			{
				name = "GF_SERVER_DOMAIN" 
				value= "example.com"
			},
			{
				name = "GF_SERVER_ROOT_URL" 
				value= "https://example.com/"
			},			
			{
				name = "GF_DATABASE_HOST" 
				value= "hostname:5432"
			},
			{
				name = "GF_DATABASE_TYPE" 
				value= "postgres"
			},
			{
				name = "GF_DATABASE_NAME" 
				value= "postgres"
			},
			{
				name = "GF_DATABASE_USER" 
				value= "grafana"
			},
			{
				name = "GF_DATABASE_SSL_MODE" 
				value= "require"
			},
			# ---------------------------------------------------------------------------------------------------------------------
			# INDICATE WHICH PLUGINS ARE INSTALLED
			# ---------------------------------------------------------------------------------------------------------------------
			{
				name = "GF_INSTALL_PLUGINS" 
				value= "${join(",",var.grafanaPlugins)}"
			},
			{
				name = "GF_SERVER_ENABLE_GZIP" 
				value= "True"
			}		
		]
		"logConfiguration": {
			"logDriver": "awslogs",
			"options": {
				"awslogs-create-group": "true",
				"awslogs-group": "/ecs/Grafana",
				"awslogs-region": "us-east-2",
				"awslogs-stream-prefix": "ecs"
			},
			"secretOptions": []
		}
    },
  ])
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE ECS SERVICE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ecs_service" "grafana" {
  name            = "grafana"
  cluster         = aws_ecs_cluster.grafana_cluster.id
  task_definition = aws_ecs_task_definition.grafana.arn
  enable_ecs_managed_tags = true
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "1.4.0" 
  
  network_configuration {
    subnets         = concat(aws_subnet.public_subnets.*.id)
    security_groups = [aws_security_group.ecs_service_security_group.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "Grafana"
    container_port   = 3000
  }


}


# ---------------------------------------------------------------------------------------------------------------------
# SECURITY GROUP FOR THE ECS SERVICE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "ecs_service_security_group" {
	name   = "grafana-ecs-access"
	vpc_id = aws_vpc.main.id
	ingress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		security_groups = [aws_security_group.alb_sg.id]
	  }  
	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	  }
}

