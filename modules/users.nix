# Features:
# - Normal users with wheel/docker/networkmanager/input/libvirtd groups, admin SSH keys, kate
{
  lib,
  pkgs,
  adminKeys,
  userNames,
  ...
}:
let
  mkUser = name: {
    isNormalUser = true;
    description = name;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "input"
      "libvirtd"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = adminKeys;
    packages = [ pkgs.kdePackages.kate ];
  };
in
{
  users.users = lib.genAttrs userNames mkUser // {
    root.openssh.authorizedKeys.keys = adminKeys;
  };
}
