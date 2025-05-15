resource "aws_eip" "this" {
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.env}-nat"
    }
  )
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public[0].id
  tags = merge(
    var.tags,
    {
      Name = "${var.env}-nat"
    }
  )

  depends_on = [aws_internet_gateway.this]
}