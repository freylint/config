.ONESHELL:

NIXOPS := nix run github:NixOS/nixops --

update: update-nixops hardware-configuration
	nix flake update
	$(NIXOPS) deploy -d default

hardware-configuration:
	nixos-generate-config --show-hardware-config > hwconfig/$$(head -c 8 /etc/machine-id).nix

update-nixops:
	nix flake update nixops

create:
	$(NIXOPS) create --flake .#default
