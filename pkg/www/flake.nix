# Features:
# - Dev shell (Node.js 22 + npm + elm) for Elm SPA; elm make compiles src/Main.elm → dist/bundle.js
# - Hot-reload dev entry point: `npm run dev` invokes `elm reactor` (bypasses serve.ts; Elm-only, no Node server)
# - HTTP server (src/serve.cjs) run directly via `node` for container deployment (non-SEA)
# - SEA build: packages serve.cjs as a single self-contained executable via `npm run dist`
{
  description = "Elm web app";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.nodejs_22
          pkgs.elmPackages.elm
        ];
      };
    };
}
