# Features:
# - workstation: KDE Plasma 6 desktop role
# - workstation_light: Sway desktop role
let
  base_workstation = import ./modules/base_workstation.nix;
  desktop = import ./modules/desktop.nix;
  sway_desktop = import ./modules/sway_desktop.nix;
  users = import ./modules/users.nix;
  home = import ./modules/home/plasma.nix;
  sway_home = import ./modules/home/sway.nix;

  workstation =
    {
      lib,
      userNames,
      plasma-manager,
      nixos-vscode-server,
      ...
    }:
    {
      imports = [
        base_workstation
        desktop
        users
      ];
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
      imports = [
        base_workstation
        sway_desktop
        users
      ];
      home-manager = {
        sharedModules = [ nixos-vscode-server.homeModules.default ];
        users = lib.genAttrs userNames (_: sway_home);
      };
    };
in
{
  inherit workstation workstation_light;
}
