# Self-tests for vscode.nix
# - Unit: VS Code enabled, key extensions present (nil, catppuccin, elm-ls), settings applied
{
  pkgs,
  nixpkgs,
  system,
  home-manager,
  nix-vscode-extensions,
}:
let
  inherit
    (import ../tests/lib.nix {
      inherit
        pkgs
        nixpkgs
        system
        home-manager
        nix-vscode-extensions
        ;
    })
    evalHome
    homePkgs
    scenario
    ;
  cfg = evalHome [ ./vscode.nix ];
  exts = cfg.programs.vscode.profiles.default.extensions;
  settings = cfg.programs.vscode.profiles.default.userSettings;
in
{
  vscode-enabled = scenario "vscode-enabled" cfg.programs.vscode.enable;
  vscode-has-nix-ide = scenario "vscode-has-nix-ide" (
    builtins.elem homePkgs.vscode-extensions.jnoortheen.nix-ide exts
  );
  vscode-has-catppuccin = scenario "vscode-has-catppuccin" (
    builtins.elem homePkgs.vscode-extensions.catppuccin.catppuccin-vsc exts
  );
  vscode-has-elm-ls = scenario "vscode-has-elm-ls" (
    builtins.elem homePkgs.vscode-extensions.elmtooling.elm-ls-vscode exts
  );
  vscode-theme-catppuccin-mocha = scenario "vscode-theme-catppuccin-mocha" (
    settings."workbench.colorTheme" == "Catppuccin Mocha"
  );
  vscode-nix-lsp-enabled = scenario "vscode-nix-lsp-enabled" (
    settings."nix.enableLanguageServer" == true
  );
}
