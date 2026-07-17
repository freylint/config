# Features:
# - KDE Plasma home-manager config: plasma theme/wallpaper, WezTerm terminal, Zsh, Baloo disabled, vkQuake entry
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
  home.sessionVariables.TERMINAL = "wezterm";
  programs = {
    plasma = {
      enable = true;
      workspace = {
        colorScheme = "CatppuccinMochaMauve";
        iconTheme = "Papirus-Dark";
        splashScreen.theme = "None";
        wallpaperPictureOfTheDay.provider = "apod";
      };
    };
    wezterm = wezterm_cfg;
    zsh = zsh_cfg;
  };
  xdg = {
    configFile."baloofilerc".text = ''
      [Basic Settings]
      Indexing-Enabled=false
    '';
    desktopEntries.vkquake = vkquakeEntry config;
  };
  services.vscode-server.enable = true;
  home.stateVersion = "26.05";
}
