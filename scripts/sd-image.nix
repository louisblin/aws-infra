{ config, lib, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/profiles/base.nix>
    <nixpkgs/nixos/modules/profiles/installation-device.nix>
    <nixpkgs/nixos/modules/installer/cd-dvd/sd-image.nix>
    ./configuration.nix
  ];

  sdImage = {
    # This might need to be increased when deploying multiple configurations.
    firmwareSize = 256;

    # TODO: check if needed.
    populateFirmwareCommands = ''
      ${config.system.build.installBootLoader} ${config.system.build.toplevel} -d ./firmware
    '';

    # /var/empty is needed for some services, such as sshd
    # XXX: This might not be needed anymore, adding to be extra sure.
    populateRootCommands = ''
      mkdir -p ./files/var/empty
      mkdir -p ./files/etc/nixos
      cp ${./configuration.nix} ./files/etc/nixos/configuration.nix
      cp ${./data.json} ./files/etc/nixos/data.json
    '';
  };

  # the installation media is also the installation target,
  # so we don't want to provide the installation configuration.nix.
  installer.cloneConfig = false;
}