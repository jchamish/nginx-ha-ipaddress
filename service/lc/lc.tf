variable "product_name" {}
variable "env_val" {}
variable "amiid" {}
variable "iamrole" {}
variable "instance_type" {}
variable "lc_sg" {
    type = list(string)
}

# creating a templte of lc
resource "aws_launch_template" "nginx_launchtemplate" {
    name = "${var.product_name}-${var.env_val}"
    image_id = var.amiid
    iam_instance_profile {
        name = var.iamrole
    }
    instance_type = var.instance_type
    monitoring {
        enabled = true
    }
    vpc_security_group_ids = var.lc_sg
    user_data = base64encode(file("ecs-userdata.txt"))
}

output "launch_template_id" {
  value = aws_launch_template.nginx_launchtemplate.id
}