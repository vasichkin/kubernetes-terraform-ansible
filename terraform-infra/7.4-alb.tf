# ALB security group: public HTTP entry point
resource "aws_security_group" "alb" {
  name        = "k8s_alb_sg"
  vpc_id      = aws_vpc.this.id
  description = "ALB: public HTTP entry point"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags, { Name = "${var.env}-alb-sg", Role = "security" })
}

resource "aws_lb" "this" {
  name               = "k8s-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = merge(var.tags, { Name = "${var.env}-alb", Role = "load-balancer" })
}

# Path patterns like "/app*" contain characters AWS tag values reject; slug them for use in names/tags
locals {
  route_slugs = { for path_key in keys(var.alb_path_routes) : path_key => replace(replace(path_key, "/", ""), "*", "") }
}

# One target group per configured path route, pointing at the worker NodePort
resource "aws_lb_target_group" "app" {
  for_each = var.alb_path_routes

  name     = substr("tg-${local.route_slugs[each.key]}", 0, 32)
  port     = each.value
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    path                = "/"
    matcher             = "200-499"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = merge(var.tags, { Name = "${var.env}-tg-${local.route_slugs[each.key]}", Role = "load-balancer" })
}

# Register every worker instance with every path route's target group on its NodePort
locals {
  worker_target_attachments = merge([
    for path_key, node_port in var.alb_path_routes : {
      for idx, instance in aws_instance.k8s_worker :
      "${path_key}-${idx}" => {
        target_group_arn = aws_lb_target_group.app[path_key].arn
        target_id        = instance.id
        port              = node_port
      }
    }
  ]...)
}

resource "aws_lb_target_group_attachment" "workers" {
  for_each = local.worker_target_attachments

  target_group_arn = each.value.target_group_arn
  target_id         = each.value.target_id
  port              = each.value.port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404 - no matching route"
      status_code  = "404"
    }
  }

  tags = merge(var.tags, { Name = "${var.env}-alb-listener-http", Role = "load-balancer" })
}

resource "aws_lb_listener_rule" "path_routes" {
  for_each = var.alb_path_routes

  listener_arn = aws_lb_listener.http.arn
  priority     = index(keys(var.alb_path_routes), each.key) + 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[each.key].arn
  }

  condition {
    path_pattern {
      values = [each.key]
    }
  }

  tags = merge(var.tags, { Name = "${var.env}-alb-rule-${local.route_slugs[each.key]}", Role = "load-balancer" })
}
