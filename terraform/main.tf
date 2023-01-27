# Get the default VPC
resource "aws_default_vpc" "default-vpn" {
  tags = {
    env = "ecs-fargate"
  }
}

# resource "aws_vpc" "ecs-fargate" {
#   cidr_block = var.cidr

#   tags = {
#     env = "ecs-fargate"
#   }
# }

# resource "aws_internet_gateway" "ecs-fargate" {
#   vpc_id = aws_vpc.ecs-fargate.id

#   tags = {
#     env = "ecs-fargate"
#   }
# }


# Get the default subnets
resource "aws_default_subnet" "subnet-A" {
  availability_zone = "eu-west-2a"
  tags = {
    env = "ecs-fargate"
  }
}

resource "aws_default_subnet" "subnet-B" {
  availability_zone = "eu-west-2b"
  tags = {
    env = "ecs-fargate"
  }
}

resource "aws_security_group" "load-balancer-sg" {
  name        = "ecs-fargate-lb-sg"
  description = "Security group for ecs-fargate"
  vpc_id      = aws_default_vpc.default-vpn.id

  # Allow inbound traffic to the loadbalancer from anywhere on port 80
  ingress {
    description = "Allow all HTTP in"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all HTTPS out"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all HTTP out"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    env = "ecs-fargate"
  }
}

resource "aws_security_group" "ecs-fargate-sg" {
  name        = "ecs-fargate-sg"
  description = "Security group for ecs-fargate"
  vpc_id      = aws_default_vpc.default-vpn.id

  # Allow HTTP traffic from the load balancer
  ingress {
    description = "Allow all HTTP in"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound requests anywhere on ports 443 & 80.connection
  # Required to pull images from DockerHub
  egress {
    description = "Allow all HTTPS out"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all HTTP out"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    env = "ecs-fargate"
  }
}

resource "aws_lb" "ecs-fargate-lb" {
  name               = "ecs-fargate-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load-balancer-sg.id]
  subnets            = [aws_default_subnet.subnet-A.id, aws_default_subnet.subnet-B.id]
  tags = {
    env = "ecs-fargate"
  }
}


resource "aws_lb_target_group" "ecs-fargate-lb-tg" {
  name        = "ecs-fargate-lb-tg"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default-vpn.id

  tags = {
    env = "ecs-fargate"
  }
}

resource "aws_lb_listener" "ecs-fargate" {
  load_balancer_arn = aws_lb.ecs-fargate-lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs-fargate-lb-tg.arn
  }
  tags = {
    env = "ecs-fargate"
  }
}


resource "aws_ecs_cluster" "ecs-fargate" {
  name = "ecs-fargate-app-cluster"
  tags = {
    env = "ecs-fargate"
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs-fargate" {
  cluster_name = aws_ecs_cluster.ecs-fargate.name

  capacity_providers = ["FARGATE"]

}

resource "aws_ecs_task_definition" "ecs-fargate" {
  family                   = "service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  container_definitions = jsonencode([
    {
      name      = "ecs-fargate-app"
      image     = "${var.image}"
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
        }
      ]
      # logConfiguration = {
      #   logDriver = "awslogs",
      #   options = {
      #     awslogs-group = "/fargate/service/${local.name}",
      #     awslogs-region = "${var.region}",
      #     awslogs-stream-prefix = "ecs"
      #   }
      # }
    }
  ])

  tags = {
    env = "ecs-fargate"
  }
}

resource "aws_ecs_service" "ecs-fargate" {
  name            = "ecs-fargate"
  cluster         = aws_ecs_cluster.ecs-fargate.id
  task_definition = aws_ecs_task_definition.ecs-fargate.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_default_subnet.subnet-A.id, aws_default_subnet.subnet-B.id]
    security_groups  = [aws_security_group.ecs-fargate-sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs-fargate-lb-tg.arn
    container_name   = "ecs-fargate-app"
    container_port   = 8000
  }

  tags = {
    env = "ecs-fargate"
  }
}