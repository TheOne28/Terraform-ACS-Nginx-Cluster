
//Network definition

resource "aws_vpc" "ecs_vpc" {
  cidr_block = var.cidr_block
}

resource "aws_subnet" "ecs_public_subnet" {
  vpc_id                  = aws_vpc.ecs_vpc.id
  count                   = length(var.public_cidr_block)
  cidr_block              = element(var.public_cidr_block, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true
}

resource "aws_subnet" "ecs_private_subnet" {
  vpc_id            = aws_vpc.ecs_vpc.id
  count             = length(var.private_cidr_block)
  cidr_block        = element(var.private_cidr_block, count.index)
  availability_zone = element(var.availability_zones, count.index)
}

resource "aws_internet_gateway" "ecs_internet_gateway" {
  vpc_id = aws_vpc.ecs_vpc.id
}

resource "aws_route" "ecs_ia" {
  route_table_id         = aws_vpc.ecs_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ecs_internet_gateway.id
}

resource "aws_eip" "ecs_nat_eip" {
  count = length(var.public_cidr_block)
  vpc   = true
  depends_on = [
    aws_internet_gateway.ecs_internet_gateway
  ]
}

resource "aws_nat_gateway" "ecs_nat_gateway" {
  count         = length(var.public_cidr_block)
  subnet_id     = element(aws_subnet.ecs_public_subnet.*.id, count.index)
  allocation_id = element(aws_eip.ecs_nat_eip.*.id, count.index)
}

resource "aws_route_table" "ecs_private_rt" {
  count  = length(aws_nat_gateway.ecs_nat_gateway)
  vpc_id = aws_vpc.ecs_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.ecs_nat_gateway.*.id, count.index)
  }
}

resource "aws_route_table_association" "subnet_route_private" {
  count          = length(var.private_cidr_block)
  subnet_id      = element(aws_subnet.ecs_private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.ecs_private_rt.*.id, count.index)
}

//Security Group Definition

resource "aws_security_group" "ecs_lb_sg" {
  vpc_id = aws_vpc.ecs_vpc.id
  name   = "lb-security-group"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow inbound traffic to load balancer on port 80"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow outbound traffic from loadbalancer to anywhere"
  }
}

resource "aws_security_group" "ecs_task_sg" {
  vpc_id = aws_vpc.ecs_vpc.id
  name   = "task-security-group"

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.ecs_lb_sg.id]
    description     = "allow inbound traffic to port 80 of the application"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow outbound traffic from application to anywhere"
  }
}

//Load balancer Definition

resource "aws_lb" "ecs_lb" {
  name               = "ecs-lb"
  internal           = false
  subnets            = aws_subnet.ecs_public_subnet.*.id
  security_groups    = [aws_security_group.ecs_lb_sg.id]
  load_balancer_type = "application"
}

resource "aws_lb_target_group" "ecs_lb_tg" {
  name        = "ecs-lb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.ecs_vpc.id
  target_type = "ip"
}

resource "aws_lb_listener" "ecs_lb_listener" {
  load_balancer_arn = aws_lb.ecs_lb.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.ecs_lb_tg.arn
    type             = "forward"
  }
}

// ECS Service Definition
resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "nginx-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 1024
  container_definitions    = <<DEFINITION
  [
    {
      "name" : "nginx",
      "image" : "nginx:1.23.1",
      "cpu" : 256,
      "memory": 1024,
      "network_mode": "awsvpc",
      "essential" : true,
      "portMappings": [
        {
          "containerPort" : 80,
          "hostPort" : 80
        }
      ]
    }
  ]
  DEFINITION
}

resource "aws_ecs_cluster" "main" {
  name = "nginx-main"
}

resource "aws_ecs_service" "ecs_service" {
  name            = "nginx-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ecs_task.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.ecs_task_sg.id]
    subnets         = aws_subnet.ecs_private_subnet.*.id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_lb_tg.id
    container_name   = "nginx"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.ecs_lb_listener
  ]
}


// Output definition

output "aws_lb_hostname" {
  value = aws_lb.ecs_lb.dns_name
}

