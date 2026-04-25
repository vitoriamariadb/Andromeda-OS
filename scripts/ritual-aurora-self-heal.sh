#!/usr/bin/env bash
# Reinstala arquivos do Ritual da Aurora a partir das cópias-fonte em
# ~/.config/zsh/scripts/. Idempotente. Roda diariamente via timer
# (e 2min pós-boot) para sobreviver a updates da System76.
set -u

SRC=/home/vitoriamaria/.config/zsh/scripts
LOG=/var/log/ritual-aurora-self-heal.log
exec >>"$LOG" 2>&1

echo "================================================================"
echo "$(date -Iseconds) — self-heal run"

if [ ! -d "$SRC" ]; then
  echo "  ERRO: $SRC não existe. Abortando."
  exit 1
fi

reload_systemd=0
reload_udev=0
restart_earlyoom=0

install_if_diff() {
  # $1=src $2=dst $3=mode $4=hook
  local src="$1" dst="$2" mode="$3" hook="$4"
  if [ ! -f "$src" ]; then
    echo "  pula: fonte ausente $src"
    return
  fi
  if [ ! -f "$dst" ] || ! cmp -s "$src" "$dst"; then
    echo "  reinstala: $dst (mode=$mode)"
    install -m "$mode" "$src" "$dst"
    case "$hook" in
      systemd) reload_systemd=1 ;;
      udev)    reload_udev=1 ;;
      earlyoom) restart_earlyoom=1; reload_systemd=1 ;;
      sysctl)  : ;;
    esac
  fi
}

install_if_diff "$SRC/ritual-aurora-root.service"          /etc/systemd/system/ritual-aurora-root.service     644 systemd
install_if_diff "$SRC/99-usb-kill-autosuspend.rules"       /etc/udev/rules.d/99-usb-kill-autosuspend.rules    644 udev
install_if_diff "$SRC/earlyoom.default"                    /etc/default/earlyoom                              644 earlyoom
install_if_diff "$SRC/50-system76-power.rules"             /etc/polkit-1/rules.d/50-system76-power.rules      644 systemd
install_if_diff "$SRC/99-meow.conf"                        /etc/sysctl.d/99-meow.conf                         644 sysctl

if [ "$reload_systemd" -eq 1 ]; then
  echo "  systemctl daemon-reload"
  systemctl daemon-reload
  systemctl enable --now ritual-aurora-root.service >/dev/null 2>&1 || true
fi
if [ "$reload_udev" -eq 1 ]; then
  echo "  udevadm reload + trigger"
  udevadm control --reload
  udevadm trigger --subsystem-match=usb --action=add
fi
if [ "$restart_earlyoom" -eq 1 ]; then
  echo "  systemctl restart earlyoom"
  systemctl restart earlyoom
fi

# Verificar se kernel param ainda está em kernelstub (System76 não mexe nisso normalmente)
if ! grep -q '"pcie_aspm=off"' /etc/kernelstub/configuration 2>/dev/null; then
  echo "  AVISO: pcie_aspm=off sumiu de kernelstub configuration — reinstalando"
  kernelstub --add-options "pcie_aspm=off" 2>&1 || echo "  ERRO ao reinstalar pcie_aspm=off"
fi

# Aplicar sysctl (idempotente)
sysctl --system >/dev/null 2>&1 || true

echo "  OK"
