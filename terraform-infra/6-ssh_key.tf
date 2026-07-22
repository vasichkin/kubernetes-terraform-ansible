# Create Aws key-pairs
resource "aws_key_pair" "this" {
  key_name   = "k8s_key"
  public_key = file("~/.ssh/id_rsa.pub")

  tags = merge(var.tags, { Name = "${var.env}-k8s-key", Role = "access" })
}