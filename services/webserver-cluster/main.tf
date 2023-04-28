
resource "aws_launch_configuration" "example" {
  instance_type = var.instance_type
  image_id = "ami-02396cdd13e9a1257"
  security_groups = [ aws_security_group.instance_sg.id ]

  user_data = templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    #db_address = data.terraform_remote_state.db.outputs.address
    #db_port = data.terraform_remote_state.db.outputs.port
  })


  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "example_asg" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier = local.availability_zone_subnet

  target_group_arns = [aws_lb_target_group.asg_target_group.arn]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key = "Name"
    value = "${var.cluster_name}-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "instance_sg" {
  name = "${var.cluster_name}-instance-sg"

  ingress  {
    from_port = var.server_port
    to_port = var.server_port
    protocol = local.tcp_protocol
    cidr_blocks = local.all_ips
  }

  egress {
    from_port        = local.any_port
    to_port          = local.any_port
    protocol         = local.any_protocol
    cidr_blocks      = local.all_ips
  }
}

resource "aws_security_group" "alb_sg" {
  name = "${var.cluster_name}-alb-sg"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id

  from_port   = local.http_port
  to_port     = local.http_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb_sg.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = local.all_ips
}


resource "aws_lb" "example_alb" {
  name = "${var.cluster_name}-alb-example"
  load_balancer_type = "application"
  subnets = local.availability_zone_subnet
  #subnets = [for subnet in aws_subnet.public : subnet.id]
  security_groups = [aws_security_group.alb_sg.id]
}

resource "aws_lb_listener" "http" {
 load_balancer_arn = aws_lb.example_alb.arn
 port = local.http_port
 protocol = "HTTP"

 default_action {
    type = "fixed-response"

# By default, return a simple 404 page
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "asg_listener_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

    condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg_target_group.arn
  }
}

resource "aws_lb_target_group" "asg_target_group" {
  name = "${var.cluster_name}-asg-target-gp"
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default_vpc.id

  health_check {
    path = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}


data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnets" "default_subnets" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.default_subnets.ids)

  id = each.key
}

locals {
  availability_zone_subnets = {
    for s in data.aws_subnet.public : s.availability_zone => s.id...
  }
}

locals {
  availability_zone_subnet = [for subnet_ids in local.availability_zone_subnets : subnet_ids[0]]
}

locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}

data "terraform_remote_state" "db" {
  backend = "s3"
  
  config = {
    bucket = var.db_remote_state_bucket
    key = var.db_remote_state_key
    region = "us-east-1"
   }
}