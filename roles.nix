# Features:
# - workstation: KDE Plasma 6 desktop role
# - workstation_xfce: XFCE desktop role
let
  base_workstation = import ./modules/base_workstation.nix;
  desktop = import ./modules/desktop.nix;
  xfce_desktop = import ./modules/xfce_desktop.nix;
  users = import ./modules/users.nix;
  home = import ./modules/home/plasma.nix;
  xfce_home = import ./modules/home/xfce.nix;

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

  workstation_xfce =
    {
      lib,
      userNames,
      nixos-vscode-server,
      ...
    }:
    {
      imports = [
        base_workstation
        xfce_desktop
        users
      ];
      home-manager = {
        sharedModules = [ nixos-vscode-server.homeModules.default ];
        users = lib.genAttrs userNames (_: xfce_home);
      };
    };
in
{
  inherit workstation workstation_xfce;
}
