# Self-tests for xfce_desktop.nix
# - Unit: XFCE desktop and SDDM enabled, battery and whiskermenu plugins in system packages
{ pkgs, nixpkgs, system, home-manager, nix-vscode-extensions }:
let
  inherit (import ./tests/lib.nix { inherit pkgs nixpkgs system home-manager nix-vscode-extensions; }) eval scenario;
  cfg = eval [ ./xfce_desktop.nix ];
in {
  xfce-desktop-enabled        = scenario "xfce-desktop-enabled"        cfg.services.xserver.desktopManager.xfce.enable;
  xfce-sddm-enabled           = scenario "xfce-sddm-enabled"           cfg.services.displayManager.sddm.enable;
  xfce-has-battery-plugin     = scenario "xfce-has-battery-plugin"     (builtins.elem pkgs.xfce4-battery-plugin    cfg.environment.systemPackages);
  xfce-has-whiskermenu-plugin = scenario "xfce-has-whiskermenu-plugin" (builtins.elem pkgs.xfce4-whiskermenu-plugin cfg.environment.systemPackages);
}
