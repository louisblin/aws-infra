{ pkgs, ssh-key, ... }:

let
  ssh-key = builtins.readFile ~/.ssh/authorized_keys;

in {
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/sd-image-aarch64.nix>
  ];

  users.users = {
    llb = {
      extraGroups = [ "wheel" ];
      isNormalUser = true;
      openssh.authorizedKeys.keys = [ ssh-key ];
      shell = pkgs.zsh;
      uid = 1001;
      packages = with pkgs; [
        htop
      ];
    };

    k3s = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [ ssh-key ];
      shell = pkgs.zsh;
      uid = 1002;
      packages = with pkgs; [
        k3s
      ];
    };
  };
}