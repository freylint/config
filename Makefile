.ONESHELL:
.PHONY: update hardware-configuration

TARGET_HOSTNAME ?= $(shell hostname)

update: hardware-configuration
	nix flake update
	NIXPKGS_ALLOW_UNFREE=1 nix run .#colmena -- apply-local --impure --node $(TARGET_HOSTNAME)

hardware-configuration:
	nixos-generate-config --show-hardware-config > hwconfig/$(TARGET_HOSTNAME).nix
	git add hwconfig/$(TARGET_HOSTNAME).nix
