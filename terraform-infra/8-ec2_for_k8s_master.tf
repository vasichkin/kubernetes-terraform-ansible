resource "aws_instance" "k8s_master" {
  ami             = var.image_ami
  instance_type   = var.k8s_master_instance_type
  key_name        = "k8s_key"
  vpc_security_group_ids = [aws_security_group.this.id]
  subnet_id              = aws_subnet.public[0].id
  depends_on      = [aws_security_group.this]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  tags = merge(
    var.tags,
    {
      Name = "k8s_master",
      Role = "k8s_master"
    }
  )
}

