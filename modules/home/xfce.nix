# Features:
# - XFCE home-manager config: WezTerm, Zsh, vkQuake desktop entry, vscode-server
let
  inherit (import ./common.nix)
    homeImports
    wezterm_cfg
    zsh_cfg
    vkquakeEntry
    ;
in
{ config, ... }: {
  imports = homeImports;
  programs = {
    wezterm = wezterm_cfg;
    zsh = zsh_cfg;
  };
  services.vscode-server.enable = true;
  xdg.desktopEntries.vkquake = vkquakeEntry config;
  home.stateVersion = "26.05";
}
