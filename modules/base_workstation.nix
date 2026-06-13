# Features:
# - Audio (pipewire), Docker, Bluetooth, SSH, printing, ntsync, gamemode, Flatpak (nix-flatpak, Bolt Launcher)
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
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
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
