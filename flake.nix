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
    fireplace-wallpaper = {
      url = "path:./pkg/fireplace-wallpaper";
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
      fireplace-wallpaper,
      sops-nix,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      adminKeys = [
        # CODEGEN-SSH-KEYS BEGIN
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIID3zQxfqqgGv8+/6wGgzurL88B3hlwTepTAKbtJ7lA+"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEmOnmo37JPC327L/32yJD1uvr2ZDMZj4mQUiS5SlPqC"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOuJ2lCWkbRz9eRQGAFOQTIiQe05ZGdIa+quR5FISPu3"
        # CODEGEN-SSH-KEYS END
        # CODEGEN-SSH-KEYS BEGIN user=lunariandreams
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJbOMuvl7nT+VuKapbIpU9kOjRluhWI1NcrspdAh5F1F"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINZ02vs+8bntaG+2l6bfHqTUawA/31dp/sRXCKs8YhAi"
        # CODEGEN-SSH-KEYS END
      ];

      userNames = [
        "gen"
        "bat"
      ];

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
            ./modules/roles/workstation.nix
          ] ++ extraModules;
          networking.hostName = name;
          deployment = deployment;
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

        defaults =
          { ... }:
          {
            deployment.buildOnTarget = true;
          };

        glw = mkHost {
          name = "glw";
          hwconfig = ./pkg/hwconfig/glw.nix;
          deployment = {
            targetHost = null;
            allowLocalDeployment = true;
          };
          extraModules = [ ./hosts/glw.nix ];
        };

        batpc = mkHost {
          name = "batpc";
          hwconfig = ./pkg/hwconfig/batpc.nix;
          deployment = {
            targetHost = "batpc.lan";
            targetUser = "root";
          };
        };

        homebase = mkHost {
          name = "homebase";
          hwconfig = ./pkg/hwconfig/homebase.nix;
          deployment = {
            targetHost = "homebase.lan";
            targetUser = "root";
          };
          extraModules = [
            fireplace-wallpaper.nixosModules.default
            ./hosts/homebase.nix
          ];
        };
      };
    };
}
