resource "aws_iam_role" "backup_and_restore" {
  name = "backup-and-restore-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "s3_full_access" {
  name        = "s3-full-access-policy"
  path        = "/"
  description = "For backup and restore scripts"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:*",
          "s3-object-lambda:*"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "backup_and_restore" {
  name       = "backup-and-restore-attachment"
  roles      = [aws_iam_role.backup_and_restore.name]
  policy_arn = aws_iam_policy.s3_full_access.arn
}

resource "aws_iam_instance_profile" "backup_and_restore" {
  name = "backup-and-restore-instance-profile"
  role = aws_iam_role.backup_and_restore.name
}