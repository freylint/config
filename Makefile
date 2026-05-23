.ONESHELL:
.PHONY: update deploy apply-local collar lock unlock ss-dev copy-ssh-key

TARGET_HOSTNAME ?= $(shell hostname)

update:
	ansible-playbook playbooks/site.yml

deploy:
	ansible-playbook playbooks/site.yml --limit $(TARGET_HOSTNAME)

apply-local:
	ansible-playbook playbooks/apply-local.yml -e target_hostname=$(TARGET_HOSTNAME)

collar:
	ansible-playbook playbooks/collar.yml

DISPLAY_SESSION := $(shell loginctl list-sessions --no-legend | awk '$$4 != "-" {print $$1}' | head -1)

lock:
	loginctl lock-session $(DISPLAY_SESSION)

unlock:
	loginctl unlock-session $(DISPLAY_SESSION)

ss-dev:
	make update; make unlock; sleep 5; make lock

copy-ssh-key:
	ssh-copy-id $(USER)@$(TARGET_HOSTNAME)
