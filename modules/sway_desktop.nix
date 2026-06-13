# Features:
# - greetd/tuigreet login, Sway WM, XDG portals (wlr+gtk), wofi/grim/slurp/wl-clipboard
{ pkgs, ... }: {
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
      user = "greeter";
    };
  };
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
  environment = {
    sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
      XDG_CURRENT_DESKTOP = "sway";
    };
    systemPackages = with pkgs; [
      wofi
      grim
      slurp
      wl-clipboard
    ];
  };
  security.polkit.enable = true;
}
