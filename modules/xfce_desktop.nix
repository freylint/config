# Features:
# - SDDM display manager, XFCE desktop environment, XDG portal (GTK)
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
  environment.systemPackages = with pkgs; [ pavucontrol ];
}
