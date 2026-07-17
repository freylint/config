# Features:
# - Quarto CLI (via nixpkgs overlay: pandoc-cli 3.7 compat + Python env wired as QUARTO_PYTHON)
# - Python env: ipykernel, jupyter-client, nbclient, nbformat, matplotlib, numpy, pyyaml
{ pkgs, ... }:
{
  nixpkgs.overlays = [
    (
      final: prev:
      let
        pythonEnv = prev.python3.withPackages (
          ps: with ps; [
            ipykernel
            jupyter-client
            nbclient
            nbformat
            matplotlib
            numpy
            pyyaml
          ]
        );
        quartoPatched = prev.quarto.overrideAttrs (old: {
          postFixup = (old.postFixup or "") + ''
            substituteInPlace $out/bin/quarto.js \
              --replace-fail 'kSyntaxHighlighting = "syntax-highlighting"' \
                             'kSyntaxHighlighting = "highlight-style"'
          '';
        });
      in
      {
        quarto = prev.symlinkJoin {
          name = "quarto-${prev.quarto.version}";
          paths = [ quartoPatched ];
          nativeBuildInputs = [ prev.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/quarto \
              --set QUARTO_PYTHON "${pythonEnv}/bin/python3"
          '';
        };
      }
    )
  ];
  environment.systemPackages = [ pkgs.quarto ];
}
