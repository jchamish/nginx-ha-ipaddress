import pathlib
import docker
import argparse
import json
import logging

from python_terraform import *

# Log to file & stdout
logging.basicConfig(filename="prod_replay_util.log", level=logging.INFO)
logging.getLogger().addHandler(logging.StreamHandler())

def create_stack() -> None:
    """
    Create a new stack from [start_date, end_date) with a given
    number of threads.
    :param info: Start Date, End Date, and # of Threads
    """
    logging.info("Creating new ")
    # Subtract 1 hour (as AWS is funky) to make this work as expected: [Inclusive, Exclusive)
    

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


def create_images(info: argparse.Namespace) -> None:
    """
    Create images
    :param info: Args
    """
    cwd = pathlib.Path().cwd()
    home_dir = cwd.parent.parent
    client_docker = docker.from_env()

    # Generate the dockerfile
    # Copy the modules
    if cwd.joinpath(app).exists():
        shutil.rmtree(cwd.joinpath(app))
        shutil.copytree(str(home_dir.joinpath(app)), str(cwd.joinpath(app)))
        # Build image
    client_docker.images.build(
        path='.',
        tag=f"build_{app}:latest"
    )
    # clean up path after
    shutil.rmtree(str(cwd.joinpath(app)))


if __name__ == "__main__":
    args =  parse_args()
    args.func()
