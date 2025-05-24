resource "aws_iam_policy" "ec2-instance-access" {
  name        = "ec2-instances-access"
  tags = merge(
    var.tags,
    {
      Name = "${var.env}-instance-policy"
    }
  )
  description = "Allow EC2 instance to access resources"
  policy      = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ec2:AttachVolume",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteSnapshot",
          "ec2:DeleteTags",
          "ec2:DeleteVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeAttribute",
          "ec2:ModifyVolume",
          "ec2:DetachVolume"
        ],
        "Resource": "*"
      }
    ]
  })
}