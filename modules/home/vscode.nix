{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions =
        (with pkgs.vscode-extensions; [
          anthropic.claude-code
          jnoortheen.nix-ide
          catppuccin.catppuccin-vsc
          mshr-h.veriloghdl
          antyos.openscad
          ms-vscode-remote.remote-ssh
          signageos.signageos-vscode-sops
        ])
        ++ (with pkgs.vscode-marketplace; [
          slevesque.shader
          timgjones.hlsltools
          raczzalan.webgl-glsl-editor
        ]);
      userSettings = {
        "editor.fontFamily" = "'FiraCode Nerd Font', monospace";
        "editor.fontLigatures" = true;
        "terminal.integrated.fontFamily" = "'FiraCode Nerd Font'";
        "workbench.colorTheme" = "Catppuccin Mocha";
        "extensions.ignoreRecommendations" = true;
        "git.autofetch" = true;
        "sops.enabled" = true;
        "sops.creationEnabled" = false;
        "files.associations"."secrets/**/*.yaml" = "yaml";
      };
    };
  };
}
