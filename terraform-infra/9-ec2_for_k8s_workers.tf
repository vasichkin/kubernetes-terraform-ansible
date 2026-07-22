# Create Aws instance  
resource "aws_instance" "k8s_worker" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = var.k8s_worker_instance_type
  key_name        = "k8s_key"
  count           = var.k8s_worker_instance_count
  vpc_security_group_ids = [aws_security_group.worker.id]
  subnet_id       = aws_subnet.private[count.index % length(var.private_subnets)].id
  depends_on      = [aws_security_group.worker]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  tags = merge(
    var.tags,
    {
      Name = "k8s_worker-${count.index}",
      Role = "k8s_worker"
    }
  )
}
