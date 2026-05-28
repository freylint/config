# Features:
# - Dev shell (Node.js 22 + npm) for TypeScript + Mithril.js; esbuild bundles src/index.ts → dist/bundle.js
# - HTTP server (src/serve.cjs) run directly via `node` for container deployment (non-SEA)
# - SEA build: packages serve.cjs as a single self-contained executable via `npm run dist`
{
  description = "Mithril.js web app";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.nodejs_22 ];
      };
    };
}
