{ pkgs, ... }:
{
  services = {
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
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
      SUDO_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
    };
  };

  programs.ssh.askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
}
