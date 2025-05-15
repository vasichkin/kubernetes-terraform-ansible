# Filter ami dynamically
# data "aws_ami" "ubuntu" {
#  most_recent = true
#  owners      = ["099720109477"]
#  filter {
#    name   = "name"
#    values = ["${var.image_name}"]
#  }
#  filter {
#    name   = "root-device-type"
#    values = ["ebs"]
#  }
#  filter {
#    name   = "virtualization-type"
#    values = ["hvm"]
#  }
#}


resource "aws_instance" "k8s_master" {
  ami             = var.image_ami
  instance_type   = var.k8s_master_instance_type
  key_name        = "k8s_key"
  vpc_security_group_ids = [aws_security_group.this.id]
  subnet_id              = aws_subnet.public[0].id
  depends_on      = [aws_security_group.this]
  tags = merge(
    var.tags,
    {
      Name = "k8s_master",
      Role = "k8s_master"
    }
  )
}

