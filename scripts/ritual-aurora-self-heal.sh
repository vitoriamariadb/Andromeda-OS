#!/usr/bin/env bash
# Reinstala arquivos do Ritual da Aurora a partir das cópias-fonte em
# ~/.config/zsh/scripts/. Idempotente. Roda diariamente via timer
# (e 2min pós-boot) para sobreviver a updates da System76.
#
# v2: cobre gamemode.ini, ritual-aurora-clipboard-trim.{sh,service,timer}
#     e os kernel params mitigations=off + threadirqs (além de pcie_aspm=off).
# v3: cobre OpenRGB Gloway (udev, modules-load, systemd service com ExecStop
#     pra que Windows não acorde com Flashing) + acpi_enforce_resources=lax.
set -u

SRC=/home/vitoriamaria/.config/zsh/scripts
USER_HOME=/home/vitoriamaria
USER_NAME=vitoriamaria
LOG=/var/log/ritual-aurora-self-heal.log
LOG_MAX_BYTES=5242880   # 5 MB — rotaciona truncando ao iniciar quando atinge

# Rotação simples antes de abrir append: se log > 5MB, mantém últimas 1000 linhas
if [ -f "$LOG" ]; then
  log_size=$(stat -c '%s' "$LOG" 2>/dev/null || echo 0)
  if [ "$log_size" -gt "$LOG_MAX_BYTES" ]; then
    tail -n 1000 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
  fi
fi
exec >>"$LOG" 2>&1

echo "================================================================"
echo "$(date -Iseconds) — self-heal run (v3)"

if [ ! -d "$SRC" ]; then
  echo "  ERRO: $SRC não existe. Abortando."
  exit 1
fi

reload_systemd=0
reload_udev=0
restart_earlyoom=0
restart_openrgb=0
errors=0

err() {
  echo "  ERRO: $*"
  errors=$((errors + 1))
}

install_if_diff() {
  # $1=src $2=dst $3=mode $4=hook
  local src="$1" dst="$2" mode="$3" hook="$4"
  if [ ! -f "$src" ]; then
    echo "  pula: fonte ausente $src"
    return
  fi
  if [ ! -f "$dst" ] || ! cmp -s "$src" "$dst"; then
    echo "  reinstala: $dst (mode=$mode)"
    if ! install -D -m "$mode" "$src" "$dst"; then
      err "install falhou: $dst"
      return
    fi
    case "$hook" in
      systemd) reload_systemd=1 ;;
      udev)    reload_udev=1 ;;
      earlyoom) restart_earlyoom=1; reload_systemd=1 ;;
      openrgb) restart_openrgb=1 ;;
      sysctl)  : ;;
      none)    : ;;
    esac
  fi
}

install_user_if_diff() {
  # Igual ao install_if_diff mas pra arquivos no $USER_HOME (preserva owner=$USER_NAME).
  # Otimizado: stat de tamanho antes de cmp -s pra evitar I/O em arquivos grandes
  # (ex: openrgb.AppImage de 33MB lido a cada apt operation seria desperdício).
  # $1=src $2=dst $3=mode
  local src="$1" dst="$2" mode="$3"
  if [ ! -f "$src" ]; then
    echo "  pula: fonte ausente $src"
    return
  fi
  # Garantir que o diretório pai existe e é do user (install -D cria como root)
  local dst_dir
  dst_dir="$(dirname "$dst")"
  if [ ! -d "$dst_dir" ]; then
    install -d -m 755 -o "$USER_NAME" -g "$USER_NAME" "$dst_dir"
  fi
  # Fast-path: se dst existe e tem mesmo tamanho, comparar conteúdo. Se tamanho
  # difere, copiar direto (evita ler 33MB pra concluir que diferem).
  local needs_copy=0
  if [ ! -f "$dst" ]; then
    needs_copy=1
  else
    local s_src s_dst
    s_src="$(stat -c '%s' "$src" 2>/dev/null || echo 0)"
    s_dst="$(stat -c '%s' "$dst" 2>/dev/null || echo 0)"
    if [ "$s_src" != "$s_dst" ]; then
      needs_copy=1
    elif ! cmp -s "$src" "$dst"; then
      needs_copy=1
    fi
  fi
  if [ "$needs_copy" -eq 1 ]; then
    echo "  reinstala (user): $dst (mode=$mode)"
    if ! install -D -m "$mode" -o "$USER_NAME" -g "$USER_NAME" "$src" "$dst"; then
      err "install (user) falhou: $dst"
    fi
  fi
}

ensure_kernel_option() {
  local opt="$1"
  if ! grep -q "\"$opt\"" /etc/kernelstub/configuration 2>/dev/null; then
    echo "  AVISO: $opt sumiu de kernelstub configuration — reinstalando"
    kernelstub --add-options "$opt" 2>&1 || err "kernelstub falhou pra $opt"
  fi
}

# v1
install_if_diff "$SRC/ritual-aurora-root.service"          /etc/systemd/system/ritual-aurora-root.service     644 systemd
install_if_diff "$SRC/99-usb-kill-autosuspend.rules"       /etc/udev/rules.d/99-usb-kill-autosuspend.rules    644 udev
install_if_diff "$SRC/earlyoom.default"                    /etc/default/earlyoom                              644 earlyoom
install_if_diff "$SRC/50-system76-power.rules"             /etc/polkit-1/rules.d/50-system76-power.rules      644 systemd
install_if_diff "$SRC/99-meow.conf"                        /etc/sysctl.d/99-meow.conf                         644 sysctl
install_if_diff "$SRC/ritual-aurora-self-heal.service"     /etc/systemd/system/ritual-aurora-self-heal.service 644 systemd
install_if_diff "$SRC/ritual-aurora-self-heal.timer"       /etc/systemd/system/ritual-aurora-self-heal.timer  644 systemd

# v2
install_if_diff "$SRC/gamemode.ini"                        /etc/gamemode.ini                                       644 none
install_if_diff "$SRC/ritual-aurora-clipboard-trim.sh"     /usr/local/bin/ritual-aurora-clipboard-trim.sh          755 none
install_if_diff "$SRC/ritual-aurora-clipboard-trim.service" /etc/systemd/user/ritual-aurora-clipboard-trim.service 644 none
install_if_diff "$SRC/ritual-aurora-clipboard-trim.timer"  /etc/systemd/user/ritual-aurora-clipboard-trim.timer    644 none

# v3: OpenRGB Gloway (system-level)
install_if_diff "$SRC/60-openrgb.rules"                    /etc/udev/rules.d/60-openrgb.rules                      644 udev
install_if_diff "$SRC/openrgb-modules.conf"                /etc/modules-load.d/openrgb.conf                        644 none
install_if_diff "$SRC/openrgb-gloway-set-static.sh"        /usr/local/bin/openrgb-gloway-set-static.sh             755 openrgb
install_if_diff "$SRC/openrgb-gloway.service"              /etc/systemd/system/openrgb-gloway.service              644 systemd

# v3: OpenRGB Gloway (user autostart — chama o mesmo script do service como
# fallback se o system service falhou. Profile v5 (gloway-roxo.orp) foi
# abandonado pq AppImage 0.9 só lê v4; script aplica via comandos diretos.)
install_user_if_diff "$SRC/openrgb-gloway.desktop"         "$USER_HOME/.config/autostart/openrgb-gloway.desktop"   644

# v3: OpenRGB AppImage (binário ~30MB; fonte-de-verdade no scripts/). Após
# install, marca restart_openrgb=1 pra trigger o service e re-aplicar Static.
# v3.1: install_user_if_diff usa fast-path stat antes de cmp -s (evita ler 30MB
# em runs sem mudança).
appimg_changed=0
if [ ! -f "$USER_HOME/.local/bin/openrgb" ] || \
   ! cmp -s "$SRC/openrgb.AppImage" "$USER_HOME/.local/bin/openrgb"; then
  appimg_changed=1
fi
install_user_if_diff "$SRC/openrgb.AppImage"               "$USER_HOME/.local/bin/openrgb"                         755
[ "$appimg_changed" = 1 ] && restart_openrgb=1

# v3: Dual-boot defender (modo silent — só age se Windows recriou bootmgfw.efi)
install_if_diff "$SRC/dual-boot-defender.sh"               /usr/local/sbin/dual-boot-defender.sh                   755 none

# v3: apt hook (fecha janela entre apt full-upgrade e próximo timer)
install_if_diff "$SRC/99-ritual-aurora-apt-hook"           /etc/apt/apt.conf.d/99-ritual-aurora-self-heal          644 none

if [ "$reload_systemd" -eq 1 ]; then
  echo "  systemctl daemon-reload"
  systemctl daemon-reload
  systemctl enable --now ritual-aurora-root.service >/dev/null 2>&1 || true
  systemctl enable --now ritual-aurora-self-heal.timer >/dev/null 2>&1 || true
  systemctl enable --now openrgb-gloway.service >/dev/null 2>&1 || true
fi
if [ "$reload_udev" -eq 1 ]; then
  echo "  udevadm reload + trigger"
  udevadm control --reload
  udevadm trigger --subsystem-match=usb --action=add
  udevadm trigger --subsystem-match=i2c-dev --action=add 2>/dev/null || true
fi
if [ "$restart_earlyoom" -eq 1 ]; then
  echo "  systemctl restart earlyoom"
  systemctl restart earlyoom
fi

# OpenRGB anti-regressão: sempre rodar health check do binário, mesmo sem
# mudança de arquivo. Se o `apt upgrade` quebrou o runtime do AppImage (visto
# 2026-05-03 com 1.0rc2 → SIGSEGV), o script openrgb-gloway-set-static.sh tem
# auto-recovery (restore do source + re-download). Restart do service força
# re-aplicação do Static — sobrevive a apt upgrades sem precisar reboot.
openrgb_health=0
if [ -x "$USER_HOME/.local/bin/openrgb" ]; then
  if timeout 12 "$USER_HOME/.local/bin/openrgb" --version >/dev/null 2>&1; then
    openrgb_health=1
  else
    echo "  openrgb segfault no health check — forçando recovery via service restart"
    restart_openrgb=1
  fi
fi
if [ "$restart_openrgb" -eq 1 ]; then
  echo "  systemctl restart openrgb-gloway.service (post-upgrade ou recovery)"
  systemctl restart openrgb-gloway.service 2>&1 || err "restart openrgb-gloway falhou"
fi

# Self-heal cuida do próprio binário em /usr/local/sbin
install_if_diff "$SRC/ritual-aurora-self-heal.sh"          /usr/local/sbin/ritual-aurora-self-heal.sh             755 none

# Kernel params via kernelstub (System76 não mexe normalmente, mas garantimos)
ensure_kernel_option "pcie_aspm=off"
ensure_kernel_option "mitigations=off"
ensure_kernel_option "threadirqs"
ensure_kernel_option "acpi_enforce_resources=lax"
ensure_kernel_option "usbcore.autosuspend=-1"
ensure_kernel_option "nvidia-drm.modeset=1"

# Garantir módulos carregados em runtime (modules-load.d só pega no boot)
modprobe i2c-dev 2>/dev/null || true
modprobe i2c-piix4 2>/dev/null || true

# Garantir user no grupo i2c (idempotente)
if ! id -nG "$USER_NAME" 2>/dev/null | grep -qw i2c; then
  echo "  adicionando $USER_NAME ao grupo i2c"
  usermod -aG i2c "$USER_NAME" 2>/dev/null || true
fi

# Aplicar sysctl (idempotente)
sysctl --system >/dev/null 2>&1 || true

# Defesa anti-Windows-update (silent — sai limpo se Windows não está montável)
if [ -x /usr/local/sbin/dual-boot-defender.sh ]; then
  /usr/local/sbin/dual-boot-defender.sh --silent 2>&1 || true
fi

if [ "$errors" -gt 0 ]; then
  echo "  TERMINOU COM $errors ERRO(S) — checar log acima"
  exit 1
fi

echo "  OK"
