#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_file="$script_dir/.zshrc"
oh_my_zsh_dir="$HOME/.oh-my-zsh"
zsh_custom="$oh_my_zsh_dir/custom"

if [[ ! -f "$config_file" ]]; then
  printf 'Nie znaleziono pliku konfiguracji: %s\n' "$config_file" >&2
  exit 1
fi

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
  "${sudo_cmd[@]}" apt-get install -y zsh git
elif command -v dnf >/dev/null 2>&1; then
  "${sudo_cmd[@]}" dnf install -y zsh git
elif command -v pacman >/dev/null 2>&1; then
  "${sudo_cmd[@]}" pacman -S --needed --noconfirm zsh git
else
  printf 'Nieobsługiwany menedżer pakietów. Obsługiwane: apt-get, dnf, pacman.\n' >&2
  exit 1
fi

if [[ -e "$oh_my_zsh_dir" ]]; then
  if [[ ! -f "$oh_my_zsh_dir/oh-my-zsh.sh" ]]; then
    printf 'Katalog %s już istnieje, ale nie zawiera Oh My Zsh.\n' "$oh_my_zsh_dir" >&2
    exit 1
  fi
else
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$oh_my_zsh_dir"
fi

mkdir -p "$zsh_custom/plugins"

if [[ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
    "$zsh_custom/plugins/zsh-autosuggestions"
fi

if [[ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$zsh_custom/plugins/zsh-syntax-highlighting"
fi

target_config="$HOME/.zshrc"
if [[ -e "$target_config" ]] && ! cmp -s "$config_file" "$target_config"; then
  backup_file="$target_config.backup.$(date +%Y%m%d%H%M%S)"
  cp -p "$target_config" "$backup_file"
  printf 'Poprzednia konfiguracja zachowana jako: %s\n' "$backup_file"
fi

install -m 0644 "$config_file" "$target_config"
printf 'Zainstalowano Zsh, Oh My Zsh i konfigurację: %s\n' "$target_config"
