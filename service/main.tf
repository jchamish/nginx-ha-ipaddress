provider "aws" {
    region = "us-east-1"
    profile = var.profile
}

variable "container_name" {}
variable "ec2_instance_type" {}
variable "amiid_linux" {}

variable "profile" {}

locals {
    product_name = "nginx-project"
    env = terraform.workspace
}

# Create a vpc
module "network" {
    source = "./network"
}

module "iam" {
    source = "./iam"
}

# Appilcation Load Balance
module "alb" {
    source = "./alb"
    product_name = local.product_name
    env_val = local.env
    alb_sg = module.network.sg_dmz_id
    subnets_external = module.network.public_subnet_ids
    vpc_id = module.network.vpc_id
}

# Autoscaling Group and Elastic Container Service
module "asg-ecs" {
    source = "./asg-ecs"
    env_val = local.env
    product_name = local.product_name

    # alb
    tgarn = module.alb.tg_arn
    tgarn_suffix = module.alb.tg_arn_suffix
    albarn_suffix = module.alb.alb_arn_suffic

    # ecs
    ecs_desired = 1
    ecs_min = 1
    ecs_max = 2
    ecs_iam_role = module.iam.iam_ecs_role_arn
    container_name = var.container_name

    # ec2
    ec2_instance_type = var.ec2_instance_type
    ec2_desired = 1
    ec2_min = 1
    ec2_max = 2
    instance_role = module.iam.iam_ec2_instance_arn
    amiid_linux = var.amiid_linux

    # network
    vpc_id = module.network.vpc_id
    sg_id = module.network.public_subnet_ids
}
