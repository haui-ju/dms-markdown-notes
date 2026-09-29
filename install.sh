#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell"
PLUGIN_ID="markdownNotes"
NOTES_DIR="$HOME/Notes"

mkdir -p "$CONFIG_DIR/plugins" "$NOTES_DIR"
ln -sfn "$REPO_DIR" "$CONFIG_DIR/plugins/$PLUGIN_ID"
echo "Plugin enlazado en $CONFIG_DIR/plugins/$PLUGIN_ID"

if ! command -v python3 >/dev/null; then
  echo "python3 no encontrado: activa el plugin y el widget desde Ajustes > Complementos."
  exit 0
fi

was_active=false
if systemctl --user is-active --quiet dms.service 2>/dev/null; then
  was_active=true
  systemctl --user stop dms.service
fi

python3 - "$CONFIG_DIR" "$PLUGIN_ID" <<'EOF'
import json, os, sys
config_dir, plugin_id = sys.argv[1], sys.argv[2]

def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

ps_path = os.path.join(config_dir, "plugin_settings.json")
ps = load(ps_path)
ps.setdefault(plugin_id, {})["enabled"] = True
with open(ps_path, "w") as f:
    json.dump(ps, f, indent=2)

s_path = os.path.join(config_dir, "settings.json")
s = load(s_path)
bars = s.get("barConfigs") or []
if bars:
    right = bars[0].setdefault("rightWidgets", [])
    if not any(isinstance(w, dict) and w.get("id") == plugin_id for w in right):
        right.insert(0, {"id": plugin_id, "enabled": True})
    with open(s_path, "w") as f:
        json.dump(s, f, indent=2)
print("Plugin activado y widget añadido a la barra")
EOF

if $was_active; then
  systemctl --user start dms.service
fi

cat <<EOF

Listo. Atajo sugerido para Hyprland:
  bind = SUPER, N, exec, dms ipc call $PLUGIN_ID toggle
EOF
