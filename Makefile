.ONESHELL:
.PHONY: update deploy hardware-configuration lock unlock

TARGET_HOSTNAME ?= $(shell hostname)

update: hardware-configuration
	nix flake update
	nix fmt .
	sudo git config --global --add safe.directory $(CURDIR)
	sudo NIXPKGS_ALLOW_UNFREE=1 nix run .#colmena -- apply-local --impure --node $(TARGET_HOSTNAME)

deploy:
	NIXPKGS_ALLOW_UNFREE=1 nix run .#colmena -- apply --on $(TARGET_HOSTNAME) --impure

deploy-homebase:
	NIXPKGS_ALLOW_UNFREE=1 nix run .#colmena -- apply --on homebase --impure

DISPLAY_SESSION := $(shell loginctl list-sessions --no-legend | awk '$$4 != "-" {print $$1}' | head -1)

lock:
	loginctl lock-session $(DISPLAY_SESSION)

unlock:
	loginctl unlock-session $(DISPLAY_SESSION)

copy-ssh-key:
	ssh-copy-id $(USER)@$(TARGET_HOSTNAME)

fetch-hwconfig:
	scp $(USER)@$(TARGET_HOSTNAME):/etc/nixos/hardware-configuration.nix hwconfig/$(TARGET_HOSTNAME).nix
	git add hwconfig/$(TARGET_HOSTNAME).nix

hardware-configuration:
	nixos-generate-config --show-hardware-config > hwconfig/$(TARGET_HOSTNAME).nix
	git add hwconfig/$(TARGET_HOSTNAME).nix
