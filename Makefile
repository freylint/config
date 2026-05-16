.ONESHELL:

update: hardware-configuration
	nix flake update
	nix run nixpkgs#colmena -- apply-local

hardware-configuration:
	nixos-generate-config --show-hardware-config > hwconfig/$$(head -c 8 /etc/machine-id).nix
