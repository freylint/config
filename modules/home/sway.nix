# Features:
# - Sway home-manager config: waybar (Nerd Font + Catppuccin Mocha), mako, swaylock/swayidle, WezTerm, Zsh, vkQuake entry
let
  inherit (import ./common.nix)
    homeImports
    wezterm_cfg
    zsh_cfg
    vkquakeEntry
    ;
in
{ pkgs, config, ... }:
let
  swaylockCmd = "${pkgs.swaylock}/bin/swaylock -f";
in
{
  imports = homeImports;
  wayland.windowManager.sway = {
    enable = true;
    config = {
      modifier = "Mod4";
      terminal = "wezterm";
      menu = "wofi --show drun";
      bars = [ { command = "waybar"; } ];
      startup = [ { command = "mako"; } ];
    };
  };
  programs = {
    waybar = {
      enable = true;
      settings = [
        {
          layer = "top";
          position = "top";
          modules-left = [
            "sway/workspaces"
            "sway/mode"
          ];
          modules-center = [ "clock" ];
          modules-right = [
            "pulseaudio"
            "network"
            "cpu"
            "memory"
            "battery"
            "tray"
          ];
          "sway/workspaces".format = "{icon}";
          clock = {
            format = " {:%H:%M}";
            format-alt = " {:%Y-%m-%d}";
          };
          cpu.format = " {usage}%";
          memory.format = " {}%";
          battery = {
            format = "{icon} {capacity}%";
            format-charging = " {capacity}%";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
            ];
          };
          network = {
            format-wifi = " {essid}";
            format-ethernet = " {ipaddr}";
            format-disconnected = " Disconnected";
          };
          pulseaudio = {
            format = "{icon} {volume}%";
            format-muted = " Muted";
            format-icons.default = [
              ""
              ""
              ""
            ];
          };
        }
      ];
      style = ''
        * { font-family: "FiraCode Nerd Font", monospace; font-size: 13px; border: none; border-radius: 0; min-height: 0; color: #cdd6f4; background: transparent; }
        window#waybar { background-color: #1e1e2e; }
        #workspaces button { color: #cdd6f4; background: transparent; padding: 0 6px; }
        #workspaces button.active { color: #cba6f7; }
        #workspaces button.urgent { color: #f38ba8; }
        #clock, #cpu, #memory, #network, #pulseaudio, #battery, #tray { padding: 0 10px; color: #cdd6f4; }
        #battery.charging { color: #a6e3a1; }
        #battery.warning:not(.charging) { color: #f9e2af; }
        #battery.critical:not(.charging) { color: #f38ba8; }
      '';
    };
    swaylock.settings.color = "1e1e2e";
    wezterm = wezterm_cfg;
    zsh = zsh_cfg;
  };
  services = {
    mako.enable = true;
    swayidle = {
      enable = true;
      events = {
        before-sleep = swaylockCmd;
      };
      timeouts = [
        {
          timeout = 600;
          command = swaylockCmd;
        }
      ];
    };
    vscode-server.enable = true;
  };
  xdg.desktopEntries.vkquake = vkquakeEntry config;
  home.stateVersion = "26.05";
}
