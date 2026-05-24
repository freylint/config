.ONESHELL:
.PHONY: deploy deploy-hosts deploy-local collar lock unlock ss-dev copy-ssh-key

TARGET_HOSTNAME ?= $(shell hostname)
ANSIBLE_PLAYBOOK := nix develop ./roles/nixops/files --command ansible-playbook
COLMENA := nix develop ./roles/nixops/files --command colmena

deploy:
	cd roles/nixops/files && NIXPKGS_ALLOW_UNFREE=1 nix develop . --command colmena apply --impure --keep-going

deploy-hosts:
	cd roles/nixops/files && NIXPKGS_ALLOW_UNFREE=1 nix develop . --command colmena apply --impure --on $(HOSTS)

deploy-local:
	$(ANSIBLE_PLAYBOOK) playbooks/apply-local.yml -e target_hostname=$(TARGET_HOSTNAME)

collar:
	$(ANSIBLE_PLAYBOOK) playbooks/collar.yml

DISPLAY_SESSION := $(shell loginctl list-sessions --no-legend | awk '$$4 != "-" {print $$1}' | head -1)

lock:
	loginctl lock-session $(DISPLAY_SESSION)

unlock:
	loginctl unlock-session $(DISPLAY_SESSION)

ss-dev:
	make update; make unlock; sleep 5; make lock

copy-ssh-key:
	SSH_ASKPASS="" ssh-copy-id $(USER)@$(TARGET_HOSTNAME)