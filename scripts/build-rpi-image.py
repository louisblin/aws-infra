#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 python3Packages.click python3Packages.retrying terraform_0_14 zstd

import json
import logging
import os
import subprocess
from contextlib import contextmanager
from pathlib import Path
from typing import List
from shlex import quote

import click
from retrying import retry

PROJECT_ROOT = Path(__file__).parent.parent.resolve()
RPI_IMAGE_BUILDER = PROJECT_ROOT / "deployment-units/rpi-image-builder"
NIXOS_CONFIG = PROJECT_ROOT / "scripts/sd-image.nix"


def call(cmd, **kwargs) -> subprocess.CompletedProcess:
    logging.debug("Running '%s' ...", " ".join(cmd))
    cp = subprocess.run(cmd, text=True, **kwargs)
    cp.check_returncode()
    logging.debug("Running '%s' ... exited (%s)", " ".join(cmd), cp.returncode)
    return cp


def terraform(args: List, **kwargs) -> subprocess.CompletedProcess:
    return call(["terraform"] + args, cwd=RPI_IMAGE_BUILDER, **kwargs)


def ssh(args: List, **kwargs) -> subprocess.CompletedProcess:
    return call(["ssh", "-o", "StrictHostKeyChecking=no"] + args, **kwargs)


def rsync(args: List, **kwargs) -> subprocess.CompletedProcess:
    return call(["rsync", "-e", "ssh -o StrictHostKeyChecking=no"] + args, **kwargs)


@contextmanager
def rpi_builder(ssh_key: str, skip_cleanup: bool):
    logging.info("Creating builder on AWS ...")

    tf_args = ["-auto-approve", "-var", f"ssh_key={ssh_key}"]
    terraform(["init"])
    terraform(["apply"] + tf_args)
    ip = terraform(["output", "-raw", "ip"], capture_output=True).stdout.strip()
    builder = f"root@{ip}"

    retry(wait_fixed=3000, stop_max_attempt_number=10)(ssh)([builder, "whoami"])

    try:
        yield builder
    except Exception:
        logging.exception("An error occured. Rerun script to retry.")
    else:
        if skip_cleanup:
            logging.info("Skipping clean-up of builder on AWS ...")
        else:
            logging.info("Destroying builder on AWS ...")
            terraform(["destroy"] + tf_args)


@click.command()
@click.option("--ssh-key", default=Path("~/.ssh/id_rsa.pub").expanduser(), type=click.File())
@click.option("--wifi-ssid", help="SSID of the WiFi to connect to")
@click.option("--wifi-psk", help="Password of the WiFi to connect to")
@click.option("--skip-cleanup", is_flag=True, help="Do not clean up the EC2 builder on exit")
@click.option("-v", "--verbose", count=True)
def main(ssh_key: click.File, wifi_ssid: str, wifi_psk: str, skip_cleanup: bool, verbose: bool):
    """
    Builds a NixOS SD image for a Raspberry Pi 4 from the given NixOS config.
    """
    logging.basicConfig(format="[%(asctime)-15s %(levelname)+8s] %(message)s", level=logging.WARNING - 10 * verbose)
    logging.info("Build NixOS image from %s", NIXOS_CONFIG)

    ssh_key = ssh_key.read().strip()
    sd_config = {
        "ssh-key": ssh_key,
        "wifi-ssid": wifi_ssid,
        "wifi-psk": wifi_psk,
    }

    with rpi_builder(ssh_key, skip_cleanup) as builder:
        logging.info("Building image on %s ...", builder)
        # TODO: switch to NixOS/nixpkgs:nixos-* branches instead
        # ssh([builder, "nix-channel", "--add", "https://nixos.org/channels/nixos-unstable", "nixos"])
        ssh([builder, "nix-channel", "--update"])

        rsync(["-arvc", str(NIXOS_CONFIG), str(NIXOS_CONFIG.parent / "configuration.nix"), f"{builder}:"])
        ssh([builder, "echo", quote(json.dumps(sd_config)), ">data.json"])
        ssh([builder, "nix-build", "'<nixpkgs/nixos>'", "-vA", "config.system.build.sdImage", "-I", f"nixos-config=./{NIXOS_CONFIG.name}"])

        logging.info("Fetching image from %s ...", builder)
        remote_image_path = Path(ssh([builder, "realpath", "./result/sd-image/*"], capture_output=True).stdout.strip())
        rsync(["-arvc", f"{builder}:{remote_image_path}", "."])
        call(["unzstd", remote_image_path.name])
        os.unlink(remote_image_path.name)

    logging.info("Done")


if __name__ == '__main__':
    main()
