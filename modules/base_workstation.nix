# Features:
# - Audio (pipewire + ALSA 32-bit + PulseAudio compat), Bluetooth (blueman)
# - Docker, SSH, printing, NetworkManager, systemd-boot EFI bootloader
# - Gaming: gamemode, Steam, ALVR VR, ntsync udev rule + kernel module (Linux 6.14+)
# - Flatpak (nix-flatpak): flathub remote, com.adamcake.Bolt; network-online ordering workaround
# - SOPS secrets (age via SSH host key), home-manager (global pkgs, backup on collision)
# - Fonts: FiraCode Nerd Font; locale: en_US.UTF-8 / America/New_York
# - Nix: experimental features (nix-command, flakes), nixPath pinned to system nixpkgs (nix-shell -p); Zsh system shell
# - System overlays, packages, WoL, gaming controllers via imports
{ pkgs, ... }: {
  imports = [
    ./overlays.nix
    ./packages.nix
    ./wake_on_lan.nix
    ./controllers.nix
  ];
  security.rtkit.enable = true;
  virtualisation.docker.enable = true;
  services = {
    flatpak = {
      enable = true;
      remotes = [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];
      packages = [
        {
          appId = "com.adamcake.Bolt";
          origin = "flathub";
        }
      ];
    };
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };
    blueman.enable = true;
    printing.enable = true;
    openssh.enable = true;
    udev.extraRules = ''KERNEL=="ntsync", TAG+="uaccess"'';
  };
  systemd.services.flatpak-managed-install = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };
  hardware.bluetooth.enable = true;
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelModules = [ "ntsync" ]; # requires Linux 6.14+
  };
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  networking = {
    domain = "freyground.com";
    networkmanager.enable = true;
  };
  nix = {
    nixPath = [ "nixpkgs=${pkgs.path}" ];
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  fonts.packages = [ pkgs.nerd-fonts.fira-code ];
  programs = {
    alvr.enable = true;
    gamemode.enable = true;
    steam.enable = true;
    zsh.enable = true;
  };
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupCommand = "mv \"$1\" \"$1.$(date +%Y%m%dT%H%M%S).bak\"";
  };
  system.stateVersion = "26.05";
}
