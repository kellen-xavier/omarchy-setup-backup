setup() {
  load test_helper/common

  WORKDIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORKDIR/packages" "$WORKDIR/webapps"
  cp "$REPO_ROOT/export.sh" "$WORKDIR/"
  SCRIPT="$WORKDIR/export.sh"

  # $HOME fake com uma instalação Omarchy simulada
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME/.local/share/omarchy/install"
  mkdir -p "$FAKE_HOME/.local/share/applications"
  mkdir -p "$FAKE_HOME/.config/waybar" "$FAKE_HOME/.config/git"
  export HOME="$FAKE_HOME"

  cat >"$FAKE_HOME/.local/share/omarchy/install/omarchy-base.packages" <<'EOF'
# base
btop
waybar
EOF
  cat >"$FAKE_HOME/.local/share/omarchy/install/omarchy-other.packages" <<'EOF'
base-devel
EOF

  echo '{"custom": true}' >"$FAKE_HOME/.config/waybar/config.jsonc"
  echo "[user]" >"$FAKE_HOME/.config/git/config"

  cat >"$FAKE_HOME/.local/share/applications/ChatGPT.desktop" <<'EOF'
[Desktop Entry]
Name=ChatGPT
Exec=omarchy-launch-webapp https://chatgpt.com/
EOF
  cat >"$FAKE_HOME/.local/share/applications/notepad.desktop" <<'EOF'
[Desktop Entry]
Name=Notepad
Exec=notepad-app %U
EOF

  # pacman/flatpak fake: base+waybar (default) + darktable (extra) instalados
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  cat >"$bindir/pacman" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -Qqe) printf '%s\n' btop waybar darktable ;;
  -Qqm) printf '%s\n' google-chrome ;;
esac
EOF
  chmod +x "$bindir/pacman"
  cat >"$bindir/flatpak" <<'EOF'
#!/usr/bin/env bash
echo "com.nvidia.geforcenow"
EOF
  chmod +x "$bindir/flatpak"
  export PATH="$bindir:$PATH"
}

@test "-h mostra o uso e sai com sucesso" {
  run "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Uso:"* ]]
}

@test "pacman-extra.txt contém só o que não está na base do Omarchy" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx "darktable" "$WORKDIR/packages/pacman-extra.txt"
  ! grep -qx "btop" "$WORKDIR/packages/pacman-extra.txt"
  ! grep -qx "waybar" "$WORKDIR/packages/pacman-extra.txt"
}

@test "aur-extra.txt reflete o pacman -Qqm" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx "google-chrome" "$WORKDIR/packages/aur-extra.txt"
}

@test "flatpak.txt reflete o flatpak list" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx "com.nvidia.geforcenow" "$WORKDIR/packages/flatpak.txt"
}

@test "webapps.txt só inclui .desktop com Exec=omarchy-launch-webapp" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx "ChatGPT|https://chatgpt.com/" "$WORKDIR/webapps/webapps.txt"
  ! grep -q "Notepad" "$WORKDIR/webapps/webapps.txt"
}

@test "dotfiles/ é atualizado com o config real do HOME fake" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$WORKDIR/dotfiles/.config/waybar/config.jsonc" ]
  grep -q '"custom": true' "$WORKDIR/dotfiles/.config/waybar/config.jsonc"
  [ -f "$WORKDIR/dotfiles/.config/git/config" ]
}
