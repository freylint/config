.ONESHELL:
.PHONY: update hardware-configuration

TARGET_HOSTNAME ?= $(shell hostname)

update: hardware-configuration
	nix flake update
	nix run .#colmena -- apply-local --node $(TARGET_HOSTNAME)

hardware-configuration:
	nixos-generate-config --show-hardware-config > hwconfig/$(TARGET_HOSTNAME).nix
	git add hwconfig/$(TARGET_HOSTNAME).nix
