# myConfig

Skrypty instalacyjne uruchamiaj z tego katalogu:

- `./install-zsh.sh` — instaluje Zsh, Oh My Zsh i pluginy, a następnie wdraża `.zshrc`.
- `./install-fonts.sh` — kopiuje fonty z `.fonts` i odświeża cache fontów (`fc-cache`).
- `./install-conky.sh` — instaluje Conky i zależności, pyta o wariant GPU (AMD, NVIDIA, Intel lub bez GPU), wdraża konfigurację i ustawia autostart.
- `./install-terminal.sh` — stosuje ustawienia kolorów i fontu Xfce Terminal z `xfce4-terminal.xml`.

Skrypty Conky i terminala są przeznaczone dla środowiska Xfce. NVIDIA wymaga zainstalowanego sterownika udostępniającego `nvidia-smi`.
