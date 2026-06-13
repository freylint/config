# Features:
# - workstation: KDE Plasma 6 desktop role — base_workstation + desktop + plasma home-manager
# - workstation_light: Sway desktop role — base_workstation + sway_desktop + sway home-manager
let
  mods = import ./modules.nix;
  inherit (mods) base_workstation desktop sway_desktop users home sway_home;

  workstation =
    {
      lib,
      userNames,
      plasma-manager,
      nixos-vscode-server,
      ...
    }:
    {
      imports = [ base_workstation desktop users ];
      home-manager = {
        sharedModules = [
          plasma-manager.homeModules.plasma-manager
          nixos-vscode-server.homeModules.default
        ];
        users = lib.genAttrs userNames (_: home);
      };
    };

  workstation_light =
    {
      lib,
      userNames,
      nixos-vscode-server,
      ...
    }:
    {
      imports = [ base_workstation sway_desktop users ];
      home-manager = {
        sharedModules = [ nixos-vscode-server.homeModules.default ];
        users = lib.genAttrs userNames (_: sway_home);
      };
    };
in
{
  inherit workstation workstation_light;
}
