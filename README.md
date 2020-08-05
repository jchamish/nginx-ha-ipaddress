# NGINX HA IP Address

## Prerequisites
- AWS Developer Account with administrator promissions
    - [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) - this the command line for Amazon Web Services.
- [Terraform 0.12.28](https://learn.hashicorp.com/terraform/getting-started/install.html) - used to build the infrastructure       
- [Python 3.8](https://www.python.org/downloads/) - implement script to help setup system.
- [dos2unix](https://waterlan.home.xs4all.nl/dos2unix/dos2unix-7.4.1-win64.zip) - need to change the format to different versions.

## How to run
1) **ONLY WINDOWS** - make sure you run dos2unix when on windows

- Windows Powershell
```bash
  dos2unix ./nginx-image/envsubst-on-templates.sh
  dos2unix ./nginx-image/docker-entrypoint.sh
  dos2unix ./nginx-image/listen-on-ipv6-by-default.sh
```

2) Setup the AWS credentials

This involves using the aws cli the command is as follow:

```bash
aws configure
```

After your prompted enter your AWS Access Key and then the AWS Secret Acccess Key. For the default region I'm using `us-east-1` but can us any region.

3) Install python dependencies

- Windows Powershell:
```bash
python -m pip install -r requirements.txt
```
- Linux and Mac Terminal
```bash
python3.8 -m pip install -r requirements.txt
```

4) Apply the Terraform

- Linux Terminal and Windows Powershell
```bash
cd service
terraform init
terraform workspace new <workspace_name>
terraform apply -var 'profile=<profile-name>' -auto-approve
```
- **Known Issue** - might need to apply again if it fails because the load balance hasn't loaded before the ecs
```text
Error: InvalidParameterException: The target group with targetGroupArn arn:aws:elasticloadbalancing:us-east-1:688910865345:targetgroup/nginx-project-tg-http/6943a4f1ed8a9ffa does not have an associated load balancer. "nginx-project-ecs-test"
```
Just need to re-apply

```bash
terraform apply -var 'profile=default' -auto-approve
```

5) Create and get ECR name
- Windows Powershell

**Notice** - make sure you're in the main repo where the `main.py` is located.

```bash
 python main.py -p <profile-name> -t image
```

- Linux Terminal
```bash
 python3.7 main.py -p <profile-name> -t image
```

This program will return a message like this
```text
info: repo name is <aws-account-number>.dkr.ecr.<aws-region>.amazonaws.com/nginx-ipaddress
```

6) Upload the container

- from step #5 copy the url to ecr `<aws-account-number>.dkr.ecr.<aws-region>.amazonaws.com`

-- This will log you into ecr
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin `<aws-account-number>.dkr.ecr.<aws-region>.amazonaws.com`
```

```bash
docker push  `<aws-account-number>.dkr.ecr.<aws-region>.amazonaws.com`/nginx-ipaddress
```

7) clean up - to clean up the everything

1) remove the docker images
```
docker rmi docker rmi alpine:3.10
docker rmi `<aws-account-number>.dkr.ecr.<aws-region>.amazonaws.com`/nginx-ipaddress
```

2) destroy the terraform
```bash
terraform workspace select `<workspace_name>`
terraform apply -var 'profile=<profile-name>' -auto-approve
```


## Help Menu - main.py
```text
usage: main.py [-h] -p PROFILE [-t {image}] [-r REGION]

optional arguments:
  -h, --help            show this help message and exit
  -p PROFILE, --profile PROFILE
                        The aws profile you're going to use
  -t {image}, --type {image}
                        options of to do run - will build terraform delete - will destroy stacks and rmi docker images image - will build the image
  -r REGION, --region REGION
                        This is the aws region you are using. default is us-east-1
```