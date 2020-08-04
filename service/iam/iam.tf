# For the container
resource "aws_iam_role" "ecs_task_role" {
    name = "nginx-task-role"
    description = "This is the role for the ecs"
    assume_role_policy = data.aws_iam_policy_document.ecs_role_policy.json
}

data "aws_iam_policy_document" "ecs_role_policy" {
    statement {
        actions = [
            "s3:ListBucket",
            "s3:ListAllMyBuckets",
            "s3:GetBucketTagging",
            "s3:GetObject",
            "s3:GetObjectAcl",
            "s3:GetObjectTagging",
            "s3:GetObjectVersion",
            "s3:GetObjectVersionTagging",
            "s3:ListBucketMultipartUploads",
            "s3:ListMultipartUploadParts",
            "s3:CreateBucket",
            "s3:CreateJob",
            "s3:PutBucketVersioning",
            "s3:PutObject",
            "s3:DeleteObject"
        ]

        resources = ["*"]
    }
}

# EC2 instances

resource "aws_iam_role" "ec2_instance_role" {
    name = "nginx-ec2-instance-role"
    description = "This is the role for the ec2 instance"
    assume_role_policy = data.aws_iam_policy_document.ec2_role_policy.json
}

data "aws_iam_policy_document" "ec2_role_policy" {
    statement {
        actions = [
            "ec2:*",
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:GetRepositoryPolicy",
            "ecr:DescribeRepositories",
            "ecr:ListImages",
            "ecr:DescribeImages",
            "ecr:BatchGetImage",
            "ecr:GetLifecyclePolicy",
            "ecr:GetLifecyclePolicyPreview",
            "ecr:ListTagsForResource",
            "ecr:DescribeImageScanFindings"
        ]

        resources = ["*"]
    }
}

# Output ARN of iam roles

output "iam_ecs_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}

output "iam_ec2_instance_arn" {
  value = aws_iam_role.ec2_instance_role.arn
}
