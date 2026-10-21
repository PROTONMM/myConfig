#!/usr/bin/env bash

set -euo pipefail

#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_dir/vendor/monaspace/fonts/Frozen Fonts"
font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
install_dir="$font_dir/Monaspace"

if [[ ! -d "$source_dir" ]]; then
  printf 'Nie znaleziono fontów Monaspace: %s\n' "$source_dir" >&2
  printf 'Zainicjalizuj submoduły poleceniem: git submodule update --init --recursive\n' >&2
  exit 1
fi

if ! command -v fc-cache >/dev/null 2>&1; then
  printf 'Nie znaleziono fc-cache. Zainstaluj fontconfig i uruchom skrypt ponownie.\n' >&2
  exit 1
fi

font_count="$(find "$source_dir" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print | wc -l)"
if [[ "$font_count" -eq 0 ]]; then
  printf 'Nie znaleziono plików TTF ani OTF w %s\n' "$source_dir" >&2
  exit 1
fi

mkdir -p "$install_dir"
while IFS= read -r -d '' font_file; do
  relative_path="${font_file#"$source_dir"/}"
  destination="$install_dir/$relative_path"
  mkdir -p "$(dirname -- "$destination")"
  install -m 0644 "$font_file" "$destination"
done < <(find "$source_dir" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)

fc-cache -f "$install_dir"
printf 'Zainstalowano %s fontów Monaspace do %s\n' "$font_count" "$install_dir"
