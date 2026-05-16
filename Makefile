.ONESHELL:

update: update-nixops hardware-configuration
	nix flake update
	nixops deploy -d default

hardware-configuration:
	nixos-generate-config --show-hardware-config > hwconfig/$$(head -c 8 /etc/machine-id).nix

update-nixops:
	nix flake update nixops

create:
	nixops create --flake .#default
