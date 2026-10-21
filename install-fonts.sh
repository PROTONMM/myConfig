#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_dir/.fonts"
font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"

if [[ ! -d "$source_dir" ]]; then
  printf 'Nie znaleziono katalogu z fontami: %s\n' "$source_dir" >&2
  exit 1
fi

if ! command -v fc-cache >/dev/null 2>&1; then
  printf 'Nie znaleziono fc-cache. Zainstaluj fontconfig i uruchom skrypt ponownie.\n' >&2
  exit 1
fi

mkdir -p "$font_dir"
installed=0

while IFS= read -r -d '' font_file; do
  extension="${font_file,,}"
  case "$extension" in
    *.ttf|*.otf|*.ttc|*.otc|*.otb|*.pfa|*.pfb|*.pcf|*.pcf.gz|*.bdf|*.bdf.gz|*.dfont)
      relative_path="${font_file#"$source_dir"/}"
      destination="$font_dir/$relative_path"
      mkdir -p "$(dirname -- "$destination")"
      install -m 0644 "$font_file" "$destination"
      installed=$((installed + 1))
      ;;
  esac
done < <(find "$source_dir" -type f -print0)

if [[ "$installed" -eq 0 ]]; then
  printf 'Nie znaleziono obsługiwanych plików fontów w %s\n' "$source_dir" >&2
  exit 1
fi

fc-cache -f "$font_dir"
printf 'Zainstalowano %d plików fontów do %s\n' "$installed" "$font_dir"
