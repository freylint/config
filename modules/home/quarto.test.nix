# Self-tests for home/quarto.nix
# - Unit: quarto.quarto extension present, .qmd association set, keybinding registered, QUARTO_PYTHON set
{ pkgs, nixpkgs, system, home-manager, nix-vscode-extensions }:
let
  inherit (import ../tests/lib.nix { inherit pkgs nixpkgs system home-manager nix-vscode-extensions; }) evalHome homePkgs scenario;
  cfg = evalHome [ ./quarto.nix ];
  exts = cfg.programs.vscode.profiles.default.extensions;
  settings = cfg.programs.vscode.profiles.default.userSettings;
  keybindings = cfg.programs.vscode.profiles.default.keybindings;
in {
  quarto-has-extension   = scenario "quarto-has-extension"   (builtins.elem homePkgs.vscode-marketplace.quarto.quarto exts);
  quarto-qmd-association = scenario "quarto-qmd-association"  (settings."files.associations"."*.qmd" == "quarto");
  quarto-python-env-set  = scenario "quarto-python-env-set"   (cfg.home.sessionVariables.QUARTO_PYTHON != "");
  quarto-preview-binding = scenario "quarto-preview-binding"  (builtins.any (b: b.command == "quarto.preview") keybindings);
}
