# Features:
# - VS Code: extensions, FiraCode, Catppuccin Mocha, SOPS, nil Nix LSP, vscodevim, elm-ls, test-adapter-converter
{ pkgs, lib, ... }: {
  # VS Code marks nix-managed extension versions as obsolete when the symlink layout
  # changes between home-manager generations; clear on each activation.
  home.activation.clearVscodeExtensionsObsolete = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD rm -f "$HOME/.vscode/extensions/.obsolete"
  '';
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
          vscodevim.vim
          hbenl.vscode-test-explorer
          ms-vscode.test-adapter-converter
          elmtooling.elm-ls-vscode
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
        "git.confirmSync" = false;
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
        "elmLS.elmPath" = "elm";
        "elmLS.elmFormatPath" = "elm-format";
        "sops.enabled" = true;
        "sops.creationEnabled" = false;
        "files.associations"."secrets/**/*.yaml" = "yaml";
      };
    };
  };
}
