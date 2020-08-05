# ECS Role
resource "aws_iam_role" "ecs_task_role" {
    name = "nginx-task-role"
    description = "This is the role for the ecs"
    path = "/"
    assume_role_policy = <<EOF
{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                    "Service": ["ecs-tasks.amazonaws.com","ecs.amazonaws.com","ec2.amazonaws.com"]
                    },
                    "Effect": "Allow",
                    "Sid": "1"
                }
            ]
}
    EOF
}

# EC2 instances role
resource "aws_iam_role" "ec2_instance_role" {
    name = "nginx-ec2-instance-role"
    description = "This is the role for the ec2 instance"
    path = "/"
    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Action": "sts:AssumeRole",
        "Principal": {
            "Service": ["ecs-tasks.amazonaws.com","ecs.amazonaws.com","ec2.amazonaws.com"]
        },
        "Effect": "Allow",
        "Sid": "1"
        }
    ]
}
    EOF

}

# Going to make it easy and allow everything
data "aws_iam_policy_document" "open_role_policy" {
  statement {
        actions = [
            "ec2:*",
            "ecs:*",
            "ecr:*",
            "elasticloadbalancing:*",
            "ssm:*",
            "logs:*"
        ]

        resources = ["*"]
    }
}

resource "aws_iam_policy" "open_everything_policy" {
  name   = "open-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.open_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ec2_attach" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.open_everything_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.open_everything_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_role" {
  name = "ec2_instance_instance_role"
  role = aws_iam_role.ec2_instance_role.name
}

# Output ARN of iam roles
output "iam_ecs_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}

output "iam_ec2_instance" {
  value = aws_iam_role.ec2_instance_role
}

output "iam_ec2_instance_profile" {
    value = aws_iam_instance_profile.ec2_instance_role
}