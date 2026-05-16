{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Replace with output of: nixos-generate-config --show-hardware-config
}
