# Features:
# - homeImports: shared home-manager modules (firefox, gtk, home_sops, vscode, flatpak_profile)
# - wezterm_cfg: FiraCode Nerd Font + Catppuccin Mocha
# - zsh_cfg: oh-my-zsh, syntax highlighting, autosuggestion
# - vkquakeEntry: vkQuake desktop entry builder
{
  homeImports = [
    ./firefox.nix
    ./gtk.nix
    ./home_sops.nix
    ./vscode.nix
    ./flatpak_profile.nix
  ];
  wezterm_cfg = {
    enable = true;
    extraConfig = ''
      local wezterm = require("wezterm")
      return {
        font = wezterm.font("FiraCode Nerd Font", { weight = "Regular" }),
        font_size = 12.0,
        harfbuzz_features = { "calt=1", "clig=1", "liga=1" },
        color_scheme = "Catppuccin Mocha",
      }
    '';
  };
  zsh_cfg = {
    enable = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
    };
    shellAliases.wanip = "curl -s ifconfig.me && echo";
  };
  vkquakeEntry = config: {
    name = "vkQuake";
    comment = "Vulkan Quake port based on QuakeSpasm";
    exec = "vkquake -basedir ${config.home.homeDirectory}/Games/Heroic/Quake";
    icon = "vkquake";
    categories = [ "Game" ];
  };
}
