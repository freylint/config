# Features:
# - Three NixOS hosts: glw (XFCE, local), batpc, homebase — deployed via nixos-rebuild
# - glw: nixos-hardware common modules (Intel CPU microcode/VAAPI, laptop TLP, SSD fstrim); OpenRazer driver+daemon
# - glw: game launcher scripts (heroic, vkquake, runelite, bolt→runelite) via nvidia-offload + gamemoderun
# - Dev shell with sops, age, ssh-to-age
# - Docker container image (Node.js www SPA; Elm bundled via elm make + buildNpmPackage, port 8080)
# - BDD test suite: unit (eval assertions) and integration (NixOS VM) via nix flake check
# - Nix formatter (nixfmt-tree)
# - virtual-display: local NixOS module sub-flake (pkg/virtual-display) providing AMD virtual display for homebase
# - virtual-display-vm: QEMU test VM for the virtual-display module (nix run .#vdisp-vm; SSH :2222 root/root)
# - nix-flatpak: declarative Flatpak management; com.adamcake.Bolt installed on all hosts
{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

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
      nix-flatpak,
      nixos-hardware,
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

      roles = import ./roles.nix;

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

      mkHost =
        {
          name,
          hwconfig,
          role ? roles.workstation,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [
            hwconfig
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
            nix-flatpak.nixosModules.nix-flatpak
            role
            { networking.hostName = name; }
          ]
          ++ extraModules;
        };

      amdgpu = {
        services.xserver.videoDrivers = [ "amdgpu" ];
        hardware.graphics = {
          enable = true;
          enable32Bit = true;
        };
      };

      batpcPackages = with pkgs; [ prismlauncher ];

      vdispVm = self.nixosConfigurations.virtual-display-vm.config.system.build.vm;
      containerPort = 8080; # Lightsail LB terminates TLS; container speaks plain HTTP
      # Fixed-output derivation: fetches elm packages (elm/browser, elm/core, elm/html + transitive deps).
      # Network access is allowed for FODs. Rebuild and update hash when elm.json deps change:
      #   nix build .#packages.x86_64-linux.container 2>&1 | grep 'got:'
      elmHome = pkgs.stdenv.mkDerivation {
        name = "www-elm-home";
        src = ./pkg/www;
        nativeBuildInputs = [
          pkgs.elmPackages.elm
          pkgs.cacert
        ];
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        outputHash = "sha256-hS+/mdQ/OKLCysE5jiVPqInz6uJcDW3n4ZnQ1jUjMok=";
        buildPhase = ''
          export ELM_HOME=$out
          mkdir -p $out
          elm make src/Main.elm --output=/dev/null
        '';
        dontInstall = true;
      };
      # $out/dist/{bundle.js,serve.cjs} + $out/index.html — __dirname in serve.ts resolves to $out/dist/
      wwwBundle = pkgs.buildNpmPackage {
        pname = "www";
        version = "0.1.0";
        src = ./pkg/www;
        # npmDepsHash covers TS devDeps: typescript ^5, @types/node ^22, esbuild ^0.24 (elm is NOT an npm dep — provided via ELM_HOME FOD above)
        # Update when npm deps change: nix build .#packages.x86_64-linux.container 2>&1 | grep 'got:'
        #   or: prefetch-npm-deps pkg/www/package-lock.json
        npmDepsHash = "sha256-XC3m7o5D+uLbBpAclsY2ThSUY48iSc4+YJN/K1Ho0hw=";
        nativeBuildInputs = [ pkgs.elmPackages.elm ];
        # elm writes a lock file to $ELM_HOME/0.19.1/packages/lock — copy to writable TMPDIR
        preBuild = ''
          export HOME=$TMPDIR
          export ELM_HOME=$TMPDIR/elm-home
          cp -r ${elmHome} $ELM_HOME
          chmod -R u+w $ELM_HOME
        '';
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
          contents = with pkgs; [
            bashInteractive
            coreutils
            nodejs_22
            wwwApp
            dockerTools.fakeNss
          ];
          config = {
            Cmd = [
              "${pkgs.nodejs_22}/bin/node"
              "${wwwApp}/dist/serve.cjs"
            ];
            ExposedPorts."${toString containerPort}/tcp" = { };
            Env = [ "PORT=${toString containerPort}" ];
          };
        };
        virtual-display-vm = vdispVm;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          sops
          age
          ssh-to-age
        ];
      };

      checks.${system} = import ./modules/tests { inherit pkgs nixpkgs system; };

      formatter.${system} = pkgs.nixfmt-tree;

      apps.${system}.vdisp-vm = {
        type = "app";
        program = nixpkgs.lib.getExe vdispVm;
      };

      nixosConfigurations = {
        virtual-display-vm = nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs.hostPlatform = system; }
            virtual-display.nixosModules.default
            ./pkg/virtual-display/vm.nix
            # nix flake check requires all nixosConfigurations to have a root fs and
            # bootloader; this is only ever run via `nix run .#vdisp-vm` (vmVariant
            # overrides at runtime), so a tmpfs root satisfies the check without effect.
            {
              boot.loader.grub.enable = false;
              fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
            }
          ];
        };

        glw = mkHost {
          name = "glw";
          hwconfig = ./hwdef/glw.nix;
          role = roles.workstation_xfce;
          extraModules = [
            nixos-hardware.nixosModules.common-cpu-intel
            nixos-hardware.nixosModules.common-pc-laptop
            nixos-hardware.nixosModules.common-pc-ssd
            (
              { pkgs, ... }:
              {
                services.xserver.videoDrivers = [ "nvidia" ];
                hardware = {
                  openrazer = {
                    enable = true;
                    users = userNames;
                  };
                  nvidia = {
                    modesetting.enable = true;
                    open = false;
                    prime = {
                      offload = {
                        enable = true;
                        enableOffloadCmd = true;
                      };
                      # Run `lspci | grep -E 'VGA|3D'` on glw and convert to PCI:<bus>:<slot>:<func>
                      intelBusId = "PCI:0:2:0";
                      nvidiaBusId = "PCI:1:0:0";
                    };
                  };
                  graphics = {
                    enable = true;
                    enable32Bit = true;
                  };
                };
                environment.systemPackages = [ pkgs.moonlight-qt pkgs.polychromatic ];
                nixpkgs.overlays = [
                  (final: prev:
                    let
                      inherit (prev) symlinkJoin makeWrapper;
                      wrapGame = drv: bin:
                        symlinkJoin {
                          inherit (drv) name;
                          paths = [ drv ];
                          nativeBuildInputs = [ makeWrapper ];
                          postBuild = ''
                            wrapProgram $out/bin/${bin} \
                              --run 'exec nvidia-offload ${final.gamemode}/bin/gamemoderun ${drv}/bin/${bin} "$@"'
                          '';
                        };
                    in
                    {
                      heroic = wrapGame prev.heroic "heroic";
                      vkquake = wrapGame prev.vkquake "vkquake";
                      runelite = wrapGame prev.runelite "runelite";
                    }
                  )
                ];
                # Bolt launches RuneLite as a child process inside its Flatpak sandbox.
                # Wrapping `flatpak run` with nvidia-offload/gamemoderun targets Bolt the
                # launcher, not RuneLite: LD_PRELOAD from gamemoderun doesn't survive the
                # sandbox boundary, and the gamemode library isn't present in the runtime.
                # A system Flatpak override injects env vars before any process in the
                # sandbox starts, so RuneLite's JVM inherits both the NVIDIA PRIME vars
                # and libgamemodeauto. The filesystems grant makes the Nix store path
                # readable inside the sandbox, which is otherwise blocked.
                environment.etc."flatpak/overrides/com.adamcake.Bolt".text = ''
                  [Environment]
                  __NV_PRIME_RENDER_OFFLOAD=1
                  __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
                  __GLX_VENDOR_LIBRARY_NAME=nvidia
                  __VK_LAYER_NV_optimus=NVIDIA_only
                  LD_PRELOAD=${pkgs.gamemode}/lib/libgamemodeauto.so.0

                  [Context]
                  filesystems=${pkgs.gamemode}/lib:ro;
                '';
              }
            )
          ];
        };

        batpc = mkHost {
          name = "batpc";
          # Prefer an existing local hardware configuration on the host itself.
          # Requires --impure when evaluated remotely.
          hwconfig =
            if builtins.pathExists /etc/nixos/hardware-configuration.nix then
              /etc/nixos/hardware-configuration.nix
            else
              ./hwdef/batpc.nix;
          extraModules = [
            {
              services.xserver.videoDrivers = [ "nvidia" ];
              hardware = {
                nvidia = {
                  modesetting.enable = true;
                  open = false;
                };
                graphics = {
                  enable = true;
                  enable32Bit = true;
                };
              };
              environment.systemPackages = batpcPackages;
            }
          ];
        };

        homebase = mkHost {
          name = "homebase";
          hwconfig = ./hwdef/homebase.nix;
          extraModules = [
            amdgpu
            # virtual-display.nixosModules.default
            (
              { pkgs, ... }:
              let
                displayTimeoutMs = 600000;
              in
              {
                # 6.18.33 hangs on boot with amdgpu.virtual_display; glw (AMD, no vdisp) boots clean
                boot.kernelPackages = pkgs.linuxPackages_zen;

                services = {
                  #virtualDisplay = {
                  #  enable = true;
                  #  amdgpuPciAddress = "0000:03:00.0";
                  #};
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
