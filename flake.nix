# Features:
# - Three NixOS hosts: glw (local), batpc, homebase — deployed via colmena
# - Dev shell with colmena, sops, age, ssh-to-age
# - Docker container image (Node.js www SPA; TypeScript+Mithril bundled via buildNpmPackage, port 8080)
# - Nix formatter (nixfmt-tree)
# - virtual-display: local NixOS module sub-flake (pkg/virtual-display) providing AMD virtual display for homebase
# - virtual-display-vm: QEMU test VM for the virtual-display module (nix run .#vdisp-vm; SSH :2222 root/root)
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
    # Local sub-flake (pkg/virtual-display) consumed as a NixOS module only.
    # Has no external inputs, so no `inputs.nixpkgs.follows` is needed.
    # `path:` inputs carry no narHash in the lock; freshness is ensured by `--impure` at deploy time.
    virtual-display.url = "path:./pkg/virtual-display";
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
      virtual-display,
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

      vdispVm = self.nixosConfigurations.virtual-display-vm.config.system.build.vm;
      containerPort = 8080; # Lightsail LB terminates TLS; container speaks plain HTTP
      # $out/dist/{bundle.js,serve.cjs} + $out/index.html — __dirname in serve.ts resolves to $out/dist/
      wwwBundle = pkgs.buildNpmPackage {
        pname = "www";
        version = "0.1.0";
        src = ./pkg/www;
        # npmDepsHash covers TS devDeps: typescript ^5, @types/mithril ^2, @types/node ^22 — rebump when these change
        npmDepsHash = "sha256-XC3m7o5D+uLbBpAclsY2ThSUY48iSc4+YJN/K1Ho0hw=";
        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp dist/bundle.js dist/serve.cjs $out/
          runHook postInstall
        '';
        dontFixup = true;
      };
      wwwApp = pkgs.runCommand "www-app" { } ''
        mkdir -p $out/dist
        cp ${./pkg/www/index.html} $out/index.html
        cp ${wwwBundle}/bundle.js ${wwwBundle}/serve.cjs $out/dist/
      '';
    in
    {
      inherit containerPort;
      packages.${system} = {
        container = pkgs.dockerTools.buildLayeredImage {
          name = "app";
          tag = "latest";
          contents = with pkgs; [ bashInteractive coreutils nodejs_22 wwwApp dockerTools.fakeNss ];
          config = {
            Cmd = [ "${pkgs.nodejs_22}/bin/node" "${wwwApp}/dist/serve.cjs" ];
            ExposedPorts."${toString containerPort}/tcp" = { };
            Env = [ "PORT=${toString containerPort}" ];
          };
        };
        virtual-display-vm = vdispVm;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ colmena sops age ssh-to-age ];
      };

      formatter.${system} = pkgs.nixfmt-tree;

      nixosConfigurations.virtual-display-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ virtual-display.nixosModules.default ./pkg/virtual-display/vm.nix ];
      };

      apps.${system}.vdisp-vm = {
        type = "app";
        program = nixpkgs.lib.getExe vdispVm;
      };

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
          deployment.allowLocalDeployment = true;
          extraModules = [
            {
              services.xserver.videoDrivers = [ "nvidia" ];
              hardware.nvidia = {
                modesetting.enable = true;
                open = false;
              };
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
            virtual-display.nixosModules.default
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
