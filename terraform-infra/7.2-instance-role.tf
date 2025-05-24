  resource "aws_iam_role" "ec2_instance_role" {
  name = "ec2-instance_role"
  # Boundary required in my case. Remove if not required
  permissions_boundary = "arn:aws:iam::418272767424:policy/DefaultBoundaryPolicy"
  tags = merge(
    var.tags,
    {
      Name = "${var.env}-instance-role"
    }
  )
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.ec2-instance-access.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
  tags = merge(
    var.tags,
    {
      Name = "${var.env}-instance-profile"
    }
  )
}