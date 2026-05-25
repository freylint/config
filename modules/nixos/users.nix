{ lib, pkgs, adminKeys, userNames, ... }:
let
  mkUser = name: {
    isNormalUser = true;
    description = name;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = adminKeys;
    packages = [ pkgs.kdePackages.kate ];
  };
in
{
  users.users =
    lib.genAttrs userNames mkUser
    // {
      root.openssh.authorizedKeys.keys = adminKeys;
    };
}
