if command -v flatpak &>/dev/null; then
  fp-browse() {
    flatpak remote-ls flathub --app --columns=application,name \
    | fzf --multi --with-nth=2 \
          --preview='flatpak remote-info flathub {1} 2>/dev/null || true' \
    | awk '{print $1}' \
    | while read -r app; do
        flatpak install -y flathub "$app" </dev/tty
      done
  }
fi
