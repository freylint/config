# Self-tests for wincompat.nix
# - Unit: system packages include bottles, wine-staging, winetricks; 32-bit graphics enabled
# - Integration: wine, bottles, winetricks binaries present and functional in a NixOS VM
{
  pkgs,
  nixpkgs,
  system,
  home-manager,
  nix-vscode-extensions,
}:
let
  inherit
    (import ./tests/lib.nix {
      inherit
        pkgs
        nixpkgs
        system
        home-manager
        nix-vscode-extensions
        ;
    })
    eval
    scenario
    vmBase
    ;
  cfg = eval [ ./wincompat.nix ];
in
{
  wincompat-has-bottles = scenario "wincompat-has-bottles" (
    builtins.elem pkgs.bottles cfg.environment.systemPackages
  );
  wincompat-has-wine-staging = scenario "wincompat-has-wine-staging" (
    builtins.elem pkgs.wineWow64Packages.staging cfg.environment.systemPackages
  );
  wincompat-has-winetricks = scenario "wincompat-has-winetricks" (
    builtins.elem pkgs.winetricks cfg.environment.systemPackages
  );
  wincompat-enables-32bit = scenario "wincompat-enables-32bit" cfg.hardware.graphics.enable32Bit;
}
// {
  wincompat-runtime = pkgs.testers.runNixOSTest {
    name = "wincompat-runtime";
    nodes.machine = { ... }: {
      imports = [
        home-manager.nixosModules.home-manager
        ./wincompat.nix
        vmBase
      ];
    };
    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("wincompat: wine reports its version (functional, no display needed)"):
          machine.succeed("wine --version")

      with subtest("wincompat: bottles binary is present in PATH"):
          machine.succeed("which bottles")

      with subtest("wincompat: winetricks binary is present in PATH"):
          machine.succeed("which winetricks")
    '';
  };
}
