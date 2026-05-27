# Features:
# - Three NixOS hosts: glw (local), batpc, homebase — deployed via colmena
# - Dev shell with colmena, sops, age, ssh-to-age
# - Docker container image (bashInteractive, port 8080)
# - Nix formatter (nixfmt-tree)
{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-vscode-extensions,
      plasma-manager,
      nur,
      rust-overlay,
      nixos-vscode-server,
      sops-nix,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      adminKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIID3zQxfqqgGv8+/6wGgzurL88B3hlwTepTAKbtJ7lA+"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEmOnmo37JPC327L/32yJD1uvr2ZDMZj4mQUiS5SlPqC"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOuJ2lCWkbRz9eRQGAFOQTIiQe05ZGdIa+quR5FISPu3"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJbOMuvl7nT+VuKapbIpU9kOjRluhWI1NcrspdAh5F1F"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINZ02vs+8bntaG+2l6bfHqTUawA/31dp/sRXCKs8YhAi"
      ];

      userNames = [
        "gen"
        "bat"
      ];

      mods = import ./modules.nix;

      mkHost =
        {
          name,
          hwconfig,
          deployment,
          extraModules ? [ ],
        }:
        { ... }:
        {
          imports = [
            hwconfig
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
            mods.workstation
          ]
          ++ extraModules;
          networking.hostName = name;
          inherit deployment;
        };

      amdgpu = {
        services.xserver.videoDrivers = [ "amdgpu" ];
        hardware.graphics = {
          enable = true;
          enable32Bit = true;
        };
      };
    in
    {
      packages.${system}.container = pkgs.dockerTools.buildLayeredImage {
        name = "app";
        tag = "latest";
        contents = with pkgs; [
          bashInteractive
          coreutils
        ];
        config = {
          Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
          ExposedPorts."8080/tcp" = { };
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          colmena
          sops
          age
          ssh-to-age
        ];
      };

      formatter.${system} = pkgs.nixfmt-tree;

      colmena = {
        meta = {
          nixpkgs = pkgs;
          specialArgs = {
            inherit
              adminKeys
              userNames
              plasma-manager
              nixos-vscode-server
              nur
              rust-overlay
              nix-vscode-extensions
              ;
          };
        };

        defaults.deployment = {
          buildOnTarget = true;
          targetUser = "root";
        };

        glw = mkHost {
          name = "glw";
          hwconfig = ./hwdef/glw.nix;
          deployment = {
            targetHost = null;
            allowLocalDeployment = true;
          };
          extraModules = [
            amdgpu
            ({ pkgs, ... }: { environment.systemPackages = [ pkgs.moonlight-qt ]; })
          ];
        };

        batpc = mkHost {
          name = "batpc";
          hwconfig = ./hwdef/batpc.nix;
          deployment.targetHost = "batpc.lan";
          extraModules = [
            {
              services.xserver.videoDrivers = [ "nvidia" ];
              hardware.nvidia.modesetting.enable = true;
              hardware.graphics = {
                enable = true;
                enable32Bit = true;
              };
            }
          ];
        };

        homebase = mkHost {
          name = "homebase";
          hwconfig = ./hwdef/homebase.nix;
          deployment.targetHost = "homebase.freyground.com";
          extraModules = [
            amdgpu
            mods.virtual_display
            (
              { ... }:
              let
                displayTimeoutMs = 600000;
              in
              {
                services = {
                  virtualDisplay = {
                    enable = true;
                    amdgpuPciAddress = "0000:03:00.0";
                  };
                  fwupd.enable = false;
                  sunshine = {
                    enable = true;
                    autoStart = true;
                    capSysAdmin = true;
                    openFirewall = true;
                  };
                };

                systemd.sleep.settings.Sleep = {
                  AllowSuspend = false;
                  AllowHibernation = false;
                };

                home-manager.users.gen = {
                  programs.plasma = {
                    kscreenlocker = {
                      autoLock = true;
                      lockOnResume = false;
                      appearance.alwaysShowClock = false;
                    };
                    configFile."kscreenlockerrc" = {
                      "Daemon" = {
                        "Timeout" = "10";
                        # Large grace period so screensaver dismisses without password prompt
                        "LockGrace" = "999999";
                      };
                    };
                    powerdevil.AC.turnOffDisplay = {
                      idleTimeout = displayTimeoutMs;
                      idleTimeoutWhenLocked = displayTimeoutMs;
                    };
                  };
                };
              }
            )
          ];
        };
      };
    };
}
