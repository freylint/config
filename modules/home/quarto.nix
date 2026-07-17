# Features:
# - VSCode: quarto.quarto extension, .qmd file association, Ctrl+Shift+K preview keybinding
# - QUARTO_PYTHON session variable and VSCode terminal env (matches system quarto overlay)
{ pkgs, ... }:
let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    ipykernel jupyter-client nbclient nbformat matplotlib numpy pyyaml
  ]);
in
{
  programs.vscode.profiles.default = {
    extensions = [ pkgs.vscode-marketplace.quarto.quarto ];
    userSettings = {
      "files.associations"."*.qmd" = "quarto";
      "terminal.integrated.env.linux"."QUARTO_PYTHON" = "${pythonEnv}/bin/python3";
    };
    keybindings = [
      { key = "ctrl+shift+k"; command = "quarto.preview"; when = "editorLangId == 'quarto'"; }
    ];
  };
  home.sessionVariables.QUARTO_PYTHON = "${pythonEnv}/bin/python3";
}
