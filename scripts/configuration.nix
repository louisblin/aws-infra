{ config, lib, pkgs, ... }:

let
  inherit (builtins.fromJSON (builtins.readFile ./data.json))
    # SSH key authorized to log on the host
    ssh-key

    # Credentials to connect to the wifi
    wifi-ssid wifi-psk;

in {
  networking.hostName = "rpi4b1";

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;

    users.root =  {
      openssh.authorizedKeys.keys = [ ssh-key ];
    };

    # The installer starts with a "nixos" user to allow installation.
    users.nixos =  {
      openssh.authorizedKeys.keys = [ ssh-key ];
      extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    };

    users.k3s = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [ ssh-key ];
    };
  };

  environment = {
    systemPackages = with pkgs; [
      htop k3s vim zsh
    ];
    variables = {
      EDITOR = "vim";
    };
  };

  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
    interactiveShellInit = ''
      source ${pkgs.grml-zsh-config}/etc/zsh/zshrc
    '';
    promptInit = ""; # otherwise it'll override the grml prompt
  };


  #####
  # k3s
  services.k3s.enable = true;
  services.k3s.extraFlags = "--tls-san 10.1.2.20";

  # TODO: add these options
  # https://aditsachde.com/posts/k3s-nix-p2/
  # systemd.services.k3s.serviceConfig.wants = [ "network-online.target" ];
  # systemd.services.k3s.serviceConfig.LimitNOFILE = "infinity";
  # systemd.services.k3s.serviceConfig.LimitNPROC = "infinity";
  # systemd.services.k3s.serviceConfig.LimitCORE = "infinity";
  # systemd.services.k3s.serviceConfig.TasksMax = "infinity";
  # systemd.services.k3s.serviceConfig.ExecStartPre = "${pkgs.kmod}/bin/modprobe -a br_netfilter overlay ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack";

  # TODO: figure out how to disable firewall, which interferes with k3s.
  networking.firewall.trustedInterfaces = [ "cni0" "eth0" "lo" ];

  #########
  # OpenSSH
  services.sshd.enable = true;
  # OpenSSH is forced to have an empty `wantedBy` on the installer system[1], this won't allow it
  # to be automatically started. Override it with the normal value.
  # [1] https://github.com/NixOS/nixpkgs/blob/9e5aa25/nixos/modules/profiles/installation-device.nix#L76
  systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];

  # NTP time sync.
  services.timesyncd.enable = true;

} // lib.optionalAttrs (wifi-ssid != null && wifi-psk != null) {

  ####################
  # WiFi configuration
  networking.wireless = {
   enable = true;
   interfaces = [ "wlan0" ];
   networks = {
     "${wifi-ssid}" = {
       psk = wifi-psk;
     };
   };
  };

  # Enables `wpa_supplicant` on boot.
  systemd.services.wpa_supplicant.wantedBy = lib.mkOverride 10 [ "default.target" ];

} // {

  #####
  # Nix
  nix = {
    autoOptimiseStore = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    # Free up to 1GiB whenever there is less than 100MiB left.
    extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
  };
  nixpkgs.config.allowUnfree = true;

  ####################
  # Boot configuration
  boot.loader.raspberryPi.enable = true;
  boot.loader.raspberryPi.version = 4;
  boot.loader.grub.enable = false;
  # boot.loader.generic-extlinux-compatible.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_rpi4;
  # Increase `cma` to 64M to allow to use all of the RAM.
  # NOTE: this disables the serial console. Add
  # "console=ttyS0,115200n8" "console=ttyAMA0,115200n8" to restore.
  boot.kernelParams = ["cma=64M" "console=tty0"];

  # boot.tmpOnTmpfs = true;
  # boot.initrd.availableKernelModules = [ "usbhid" "usb_storage" ];
  boot.consoleLogLevel = lib.mkDefault 7;

  # Required for the Wireless firmware
  # hardware.enableRedistributableFirmware = true;

  # https://github.com/Robertof/nixos-docker-sd-image-builder/blob/master/config/rpi4/default.nix
  fileSystems = lib.mkForce {
      # There is no U-Boot on the Pi 4, thus the firmware partition needs to be mounted as /boot.
      "/boot" = {
          device = "/dev/disk/by-label/FIRMWARE";
          fsType = "vfat";
      };
      "/" = {
          device = "/dev/disk/by-label/NIXOS_SD";
          fsType = "ext4";
      };
  };

  powerManagement.cpuFreqGovernor = "ondemand";
  system.stateVersion = "20.09";
  #swapDevices = [ { device = "/swapfile"; size = 3072; } ];
}