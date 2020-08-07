import pathlib
import docker
import argparse
import logging
import jmespath
import json
import boto3
import base64
import sys


from python_terraform import *

from typing import List

# Log to file & stdout
logging.basicConfig(filename="nginx-system.log", level=logging.INFO)
logging.getLogger().addHandler(logging.StreamHandler())

# GLABOLs
CWD: pathlib.Path = pathlib.Path().expanduser().resolve()
DOCKER_PATH: pathlib.Path = CWD.joinpath('nginx-image')
SERVICE_PATH: pathlib.Path = CWD.joinpath('service')
DOCKER_CLIENT = docker.from_env()


def create_docker_images_and_push(profile: str, region: str, do_push: bool = False) -> None:
    """
    Create images
    """
    # Build the current Image
    logging.info("Building the Docker Container")
    DOCKER_CLIENT.images.build(
        path=str(DOCKER_PATH),
        tag="nginx-container:latest",
        quiet=False
    )

    # search for a tf state file
    terraform = [p for p in SERVICE_PATH.rglob("*.tfstate")]

    if not terraform:
        logging.info("Can't get repo name form tfstate file")
        sys.exit(1)

    # load tf state file
    with terraform[0].open(mode='r') as fp:
        tf_state_data = json.load(fp)

    # find the repository_url
    list_of_repository_url: List[str] = jmespath.search(
            "resources[?type=='aws_ecr_repository'].instances | [0][*].attributes.repository_url",
            tf_state_data
        )
    # check we we're able to get the repo
    if list_of_repository_url:
        repository_url: str = list_of_repository_url.pop(0)
        logging.info(f"info: repo name is {repository_url}")

        # 1) re-tag with epository_url
        current_image = DOCKER_CLIENT.images.get("nginx-container:latest")
        current_image.tag(f"{repository_url}:latest")

        # 2) push image to aws
        if do_push:
            sesson = boto3.Session(profile_name=profile, region_name=region)
            ecr_client = sesson.client('ecr')

            token = ecr_client.get_authorization_token()

            registry_auth = token.get('authorizationData')
            # get auth token for ecr
            if registry_auth:
                try:
                    username, password = base64.b64decode(registry_auth[0]['authorizationToken']).decode().split(':')
                    repository_name = registry_auth[0]['proxyEndpoint']
                except IndexError as e:
                    logging.error(f"Error - {e}")

            # loging and push the image
            DOCKER_CLIENT.login(username, password, registry=repository_name)
            DOCKER_CLIENT.images.push(f"{repository_url}:latest")


def create_terrafrom(profile: str, region: str) -> None:
    """
    Create AWS structure from Terraform infrastructure
    :return: AWS Object
    """
    logging.info("Creating Terraform layout (may take a while...)")
    terraform = Terraform(working_dir=SERVICE_PATH)

    try:
        terraform.cmd("init")
    except FileNotFoundError:
        logging.error("Terraform was not found in PATH. Please do so.")
        sys.exit(1)

    terraform.cmd(f"workspace new tstack")
    terraform.cmd(f"workspace select tstack")
    return_code, _, stderr = terraform.cmd(
        "apply",
        vars=f"profile={profile}",
        auto_approve=IsFlagged
    )

    logging.info(f"Terraform Exit Code: {return_code}")

    if return_code == 0:
        logging.info("new stack created")
    else:
        if "ExpiredToken" in stderr:
            logging.critical(
                "***token expired, please renew and try again ***"
            )
        else:
            logging.critical(
                "*** Ensure aws profile exists***"
            )
        sys.exit(1)

    print(terraform.output())


def clean_up(profile: str, region: str) -> None:
    """
    remove everything created and docker images
    :param stack_id: Stack ID to delete
    """
    try:
        terraform = Terraform(working_dir=SERVICE_PATH)
        terraform.cmd("init")
        terraform.cmd(f"workspace select tstack")
    except (TerraformCommandError, KeyError):
        logging.error("workspace doesn't exist")
        sys.exit(-1)

    return_code, stdout, stderr = terraform.cmd(
        "destroy",
        var={
                "profile": profile,
                "region": region
            },
        auto_approve=IsFlagged,
    )
    logging.info(stdout)
    logging.error(stderr)

    # docker remove
    if return_code == 0:
        logging.info(f"ECS Stack tstack destroy complete")
    

def parse_args() -> argparse.Namespace:
    """
    Parse input args from the user into system args
    :return: Namespace of options
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-p",
        "--profile",
        type=str,
        required=True,
        default="default",
        help="The aws profile you're going to use"
    )
    parser.add_argument(
        "-t",
        "--type",
        type=str,
        default="run",
        choices=["image"],
        required=False,
        help="""options of to do
            run - will build terraform
            delete - will destroy stacks and rmi docker images
            image - will build the image
        """
    )
    parser.add_argument(
        "-r",
        "--region",
        type=str,
        default="us-east-1",
        required=False,
        help="This is the aws region you are using. default is us-east-1"
    )

    return parser.parse_args()


if __name__ == "__main__":
    args =  parse_args()
    
    # simple two state run
    if args.type == "run":
        # apply terrafrom
        create_terrafrom(args.profile, args.region)
    elif args.type == "image":
         # build docker image and push to ecr
        create_docker_images_and_push(args.profile, args.region)
    elif args.type == "clean":
        clean_up(args.profile, args.region)
    else:
        logging.error("Error - invalid selection")
