{ lib, userNames, plasma-manager, nixos-vscode-server, ... }:
{
  imports = [
    ../nixos/overlays.nix
    ../nixos/boot.nix
    ../nixos/networking.nix
    ../nixos/locale.nix
    ../nixos/desktop.nix
    ../nixos/audio.nix
    ../nixos/bluetooth.nix
    ../nixos/printing.nix
    ../nixos/ssh.nix
    ../nixos/packages.nix
    ../nixos/fonts.nix
    ../nixos/steam.nix
    ../nixos/shell.nix
    ../nixos/users.nix
    ../nixos/sops.nix
    ../nixos/nix.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    sharedModules = [
      plasma-manager.homeModules.plasma-manager
      nixos-vscode-server.homeModules.default
    ];
    users = lib.genAttrs userNames (_: import ../home);
  };

  system.stateVersion = "25.11";
}
