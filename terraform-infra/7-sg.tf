# Master security group: SSH + Kubernetes API, publicly reachable
resource "aws_security_group" "master" {
  name        = "k8s_master_sg"
  vpc_id      = aws_vpc.this.id
  depends_on  = [aws_vpc.this]
  description = "k8s master: SSH + API server"
  dynamic "ingress" {
    for_each = var.ports
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ var.vpc_cidr_block ]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = merge(var.tags, { Name = "${var.env}-master-sg", Role = "security" })
}

# Worker security group: NodePort app traffic only from the ALB; SSH/anything else only from inside the VPC
resource "aws_security_group" "worker" {
  name        = "k8s_worker_sg"
  vpc_id      = aws_vpc.this.id
  depends_on  = [aws_vpc.this]
  description = "k8s workers: NodePorts reachable only from the ALB"
  dynamic "ingress" {
    for_each = distinct(values(var.alb_path_routes))
    iterator = node_port
    content {
      from_port       = node_port.value
      to_port         = node_port.value
      protocol        = "tcp"
      security_groups = [aws_security_group.alb.id]
    }
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ var.vpc_cidr_block ]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = merge(var.tags, { Name = "${var.env}-worker-sg", Role = "security" })
}