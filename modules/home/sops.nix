{ pkgs, lib, ... }:
{
  home.activation.sopsAgeKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    KEY_FILE="$HOME/.config/sops/age/keys.txt"
    SSH_KEY="$HOME/.ssh/id_ed25519"
    if [ -f "$SSH_KEY" ] && [ ! -f "$KEY_FILE" ]; then
      mkdir -p "$(dirname "$KEY_FILE")"
      ${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i "$SSH_KEY" > "$KEY_FILE"
      chmod 600 "$KEY_FILE"
    fi
  '';
}
