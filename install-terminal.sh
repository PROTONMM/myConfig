#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_file="$script_dir/xfce4-terminal.xml"

if [[ ! -f "$config_file" ]]; then
  printf 'Nie znaleziono konfiguracji terminala: %s\n' "$config_file" >&2
  exit 1
fi

if ! command -v xfconf-query >/dev/null 2>&1; then
  printf 'Nie znaleziono xfconf-query. Ten skrypt wymaga Xfce i pakietu xfconf.\n' >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'Nie znaleziono python3, wymaganego do odczytania pliku XML.\n' >&2
  exit 1
fi

python3 - "$config_file" <<'PY'
import subprocess
import sys
import xml.etree.ElementTree as ET

config_file = sys.argv[1]
try:
    root = ET.parse(config_file).getroot()
except (ET.ParseError, OSError) as error:
    sys.exit(f"Nie można odczytać konfiguracji {config_file}: {error}")

if root.tag != "channel" or root.get("name") != "xfce4-terminal":
    sys.exit(f"Plik {config_file} nie jest konfiguracją kanału xfce4-terminal.")

properties = list(root)
if not properties:
    sys.exit(f"Plik {config_file} nie zawiera ustawień terminala.")

for property_node in properties:
    name = property_node.get("name")
    value = property_node.get("value")
    value_type = property_node.get("type")
    if property_node.tag != "property" or not name or value is None:
        sys.exit(f"Nieprawidłowa właściwość w pliku {config_file}.")
    if value_type not in {"string", "bool", "int", "uint", "double"}:
        sys.exit(f"Nieobsługiwany typ {value_type!r} właściwości {name!r}.")

for property_node in properties:
    name = property_node.get("name")
    value = property_node.get("value")
    value_type = property_node.get("type")
    result = subprocess.run(
        [
            "xfconf-query",
            "--channel", "xfce4-terminal",
            "--property", f"/{name}",
            "--create",
            "--type", value_type,
            "--set", value,
        ],
        text=True,
        capture_output=True,
    )
    if result.returncode:
        if result.stderr:
            sys.stderr.write(result.stderr)
        sys.exit(f"Nie udało się ustawić właściwości /{name}.")

print(f"Zastosowano {len(properties)} ustawień Xfce Terminal.")
PY
