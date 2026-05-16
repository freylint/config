.ONESHELL:

COLMENA := nix run nixpkgs#colmena --

update: hardware-configuration
	nix flake update
	$(COLMENA) apply-local

hardware-configuration:
	nixos-generate-config --show-hardware-config > hwconfig/$$(head -c 8 /etc/machine-id).nix
