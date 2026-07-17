# Features:
# - KDE Plasma 6, SDDM Wayland, ksshaskpass, excluded KDE packages, catppuccin-kde
{ pkgs, ... }:
let
  ksshaskpass = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
in
{
  services = {
    xserver = {
      enable = true;
      xkb.layout = "us";
      excludePackages = [ pkgs.xterm ];
    };
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
        settings = {
          General.Numlock = "on";
          Theme.EnableAvatars = false;
        };
      };
      defaultSession = "plasma";
    };
    desktopManager.plasma6.enable = true;
  };
  environment = {
    plasma6.excludePackages = with pkgs.kdePackages; [
      konsole
      elisa
      oxygen
      khelpcenter
      krdp
    ];
    sessionVariables = {
      SSH_ASKPASS_REQUIRE = "prefer";
      SUDO_ASKPASS = ksshaskpass;
    };
    systemPackages = [ pkgs.catppuccin-kde ];
  };
  programs.ssh.askPassword = ksshaskpass;
}
