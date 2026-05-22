.ONESHELL:
.PHONY: update deploy hardware-configuration

TARGET_HOSTNAME ?= $(shell hostname)

update: hardware-configuration
	nix flake update
	nix fmt
	NIXPKGS_ALLOW_UNFREE=1 nix run .#colmena -- apply-local --impure --node $(TARGET_HOSTNAME)

deploy:
	NIXPKGS_ALLOW_UNFREE=1 nix run .#colmena -- apply --on $(TARGET_HOSTNAME) --impure

deploy-homebase:
	NIXPKGS_ALLOW_UNFREE=1 nix run .#colmena -- apply --on homebase --impure

copy-ssh-key:
	ssh-copy-id $(USER)@$(TARGET_HOSTNAME)

fetch-hwconfig:
	scp $(USER)@$(TARGET_HOSTNAME):/etc/nixos/hardware-configuration.nix hwconfig/$(TARGET_HOSTNAME).nix
	git add hwconfig/$(TARGET_HOSTNAME).nix

hardware-configuration:
	nixos-generate-config --show-hardware-config > hwconfig/$(TARGET_HOSTNAME).nix
	git add hwconfig/$(TARGET_HOSTNAME).nix
