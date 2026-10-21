#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_dir/conky"
config_dir="$HOME/.config/conky"

if [[ ! -f "$source_dir/conky.conf" || ! -f "$source_dir/widgets.lua" ]]; then
  printf 'Nie znaleziono konfiguracji Conky w %s\n' "$source_dir" >&2
  exit 1
fi

printf 'Wybierz wariant monitorowania GPU:\n'
printf '  1) AMD\n  2) NVIDIA (wymaga sterownika NVIDIA z nvidia-smi)\n'
printf '  3) Intel\n  4) Bez GPU\n'
read -r -p 'Wybór [1-4]: ' selection

case "$selection" in
  1) gpu_mode=amd ;;
  2) gpu_mode=nvidia ;;
  3) gpu_mode=intel ;;
  4) gpu_mode=none ;;
  *)
    printf 'Nieprawidłowy wybór: %s\n' "$selection" >&2
    exit 1
    ;;
esac

if [[ "$EUID" -eq 0 ]]; then
  sudo_cmd=()
else
  if ! command -v sudo >/dev/null 2>&1; then
    printf 'Do instalacji pakietów wymagane jest sudo lub uruchomienie jako root.\n' >&2
    exit 1
  fi
  sudo_cmd=(sudo)
fi

if command -v apt-get >/dev/null 2>&1; then
  "${sudo_cmd[@]}" apt-get update
  "${sudo_cmd[@]}" apt-get install -y conky-all curl jq
elif command -v dnf >/dev/null 2>&1; then
  "${sudo_cmd[@]}" dnf install -y conky curl jq
elif command -v pacman >/dev/null 2>&1; then
  "${sudo_cmd[@]}" pacman -S --needed --noconfirm conky curl jq
else
  printf 'Nieobsługiwany menedżer pakietów. Obsługiwane: apt-get, dnf, pacman.\n' >&2
  exit 1
fi

mkdir -p "$config_dir"
backup_if_needed() {
  local source_file="$1"
  local destination="$2"
  if [[ -e "$destination" ]] && ! cmp -s "$source_file" "$destination"; then
    local backup="$destination.backup.$(date +%Y%m%d%H%M%S)"
    cp -p "$destination" "$backup"
    printf 'Poprzedni plik zachowany jako: %s\n' "$backup"
  fi
}

backup_if_needed "$source_dir/conky.conf" "$config_dir/conky.conf"
install -m 0644 "$source_dir/conky.conf" "$config_dir/conky.conf"

backup_if_needed "$source_dir/widgets.lua" "$config_dir/widgets.lua"
install -m 0644 "$source_dir/widgets.lua" "$config_dir/widgets.lua"

mode_source="$(mktemp)"
trap 'rm -f "$mode_source"' EXIT
printf '%s\n' "$gpu_mode" > "$mode_source"
backup_if_needed "$mode_source" "$config_dir/gpu-mode"
install -m 0644 "$mode_source" "$config_dir/gpu-mode"

bin_dir="${HOME}/.local/bin"
autostart_dir="${HOME}/.config/autostart"
mkdir -p "$bin_dir" "$autostart_dir"
cat > "$bin_dir/start-conky" <<'EOF'
#!/usr/bin/env sh
exec conky -c "$HOME/.config/conky/conky.conf"
EOF
chmod 0755 "$bin_dir/start-conky"

desktop_source="$(mktemp)"
trap 'rm -f "$mode_source" "$desktop_source"' EXIT
cat > "$desktop_source" <<'EOF'
[Desktop Entry]
Type=Application
Name=Conky
Comment=System monitor
Exec=sh -c "exec \"$HOME/.local/bin/start-conky\""
X-GNOME-Autostart-enabled=true
EOF
backup_if_needed "$desktop_source" "$autostart_dir/conky.desktop"
install -m 0644 "$desktop_source" "$autostart_dir/conky.desktop"

printf 'Conky skonfigurowany (wariant: %s). Uruchomi się przy następnym logowaniu.\n' "$gpu_mode"
printf 'Możesz uruchomić go teraz poleceniem: %s/.local/bin/start-conky\n' "$HOME"
