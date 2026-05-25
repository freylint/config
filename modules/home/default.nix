{ ... }:
{
  imports = [
    ./vscode-server.nix
    ./firefox.nix
    ./plasma.nix
    ./gtk.nix
    ./vscode.nix
    ./wezterm.nix
    ./zsh.nix
    ./baloo.nix
    ./sops.nix
    ./games.nix
  ];

  home.stateVersion = "25.11";
}
