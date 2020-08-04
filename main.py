import pathlib
import docker
import argparse
import json
import logging
import string


from python_terraform import *

# Log to file & stdout
logging.basicConfig(filename="prod_replay_util.log", level=logging.INFO)
logging.getLogger().addHandler(logging.StreamHandler())

#
DOCKER_PATH = pathlib.Path().parent.joinpath('nginx-image')
SERVICE_PATH = pathlib.Path().parent.joinpath('service')

def generate_random_stack_id(alph: str = string.ascii_lowercase, count: int = 5) -> str:
    """

    :param alph:
    :param count:
    """

def create_aws_stack() -> None:
    """
    Create AWS structure from Terraform unfrastructure
    :param stack_id: generator random workspace
    """
    logging.info("Creating Terraform (this process takes a bit)")

    terraform = Terraform(working_dir=SERVICE_PATH)

    try:
        terraform.init("init")
    except FileExistsError:
        logging.error("Terraform was not found in SERVICE_PATH")
        return

    terraform.cmd(f"workspace new {}")


def parse_args() -> argparse.Namespace:
    """
    Parse input args from the user into system args
    :return: Namespace of options
    """
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()

    # Create images Stack Parser
    create_docker_images = subparsers.add_parser("createimages")
    create_docker_images.add_argument(
        "-i",
        "--image-di",
        type=str,
        choices=['all', 'request_feeder', 'request_worker', 'input_feeder'],
        required=True
    )

    create_docker_images.set_defaults(func=create_images)

    return parser.parse_args()


def create_docker_images() -> None:
    """
    Create images
    """
    cwd = pathlib.Path().cwd()
    home_dir = cwd.parent.parent
    client_docker = docker.from_env()

    # Generate docker images
    client_docker.images.build(
        path='.',
        tag=f":latest"
    )

def create_terraform() -> None:
    """
       Create AWS structure from Terraform infrastructure
       :param stack_id: Stack name to pass to AWS
       :return: AWS Object
       """
    logging.info("Creating Terraform layout (this may take a while...)")

    terraform = Terraform(working_dir=PREREQ_PATH)  # type: ignore

    try:
        terraform.cmd("init")
    except FileNotFoundError:
        logging.error("Terraform was not found in PATH. Please do so.")
        sys.exit(1)

    terraform.cmd(f"workspace new {stack_id}")
    terraform.cmd(f"workspace select {stack_id}")
    return_code, _, stderr = terraform.cmd(
        "apply", auto_approve=IsFlagged  # type: ignore
    )

    logging.info(f"Terraform Exit Code: {return_code}")

    if return_code == 0:
        logging.info("Prereq stack creation complete.")
    else:
        if "ExpiredToken" in stderr:
            logging.critical(
                "*** prod-replay-user token expired, please renew and try again ***"
            )
        else:
            logging.critical(
                "*** Ensure prod-replay-user profile exists and can access QA ***"
            )
        sys.exit(1)

    prereq_outputs = terraform.output()
    return prereq_outputs


def upload_to_ecr()



if __name__ == "__main__":
    args =  parse_args()
    args.func()
