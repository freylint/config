# Features:
# - SDDM display manager, XFCE desktop environment, XDG portal (GTK)
# - Whisker Menu panel plugin (search-capable app launcher), battery plugin
{ pkgs, ... }: {
  services = {
    xserver = {
      enable = true;
      excludePackages = [ pkgs.xterm ];
      desktopManager.xfce.enable = true;
    };
    displayManager = {
      sddm.enable = true;
      defaultSession = "xfce";
    };
  };
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
  environment.systemPackages = with pkgs; [
    pavucontrol
    xfce4-battery-plugin
    xfce4-whiskermenu-plugin
  ];
}
