#!/usr/bin/env bash
# Reinstala arquivos do Ritual da Aurora a partir das cópias-fonte em
# ~/.config/zsh/scripts/. Idempotente. Roda diariamente via timer
# (e 2min pós-boot) para sobreviver a updates da System76.
#
# v2: cobre gamemode.ini, ritual-aurora-clipboard-trim.{sh,service,timer}
#     e os kernel params mitigations=off + threadirqs (além de pcie_aspm=off).
set -u

SRC=/home/vitoriamaria/.config/zsh/scripts
LOG=/var/log/ritual-aurora-self-heal.log
exec >>"$LOG" 2>&1

echo "================================================================"
echo "$(date -Iseconds) — self-heal run (v2)"

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
    install -D -m "$mode" "$src" "$dst"
    case "$hook" in
      systemd) reload_systemd=1 ;;
      udev)    reload_udev=1 ;;
      earlyoom) restart_earlyoom=1; reload_systemd=1 ;;
      sysctl)  : ;;
      none)    : ;;
    esac
  fi
}

ensure_kernel_option() {
  local opt="$1"
  if ! grep -q "\"$opt\"" /etc/kernelstub/configuration 2>/dev/null; then
    echo "  AVISO: $opt sumiu de kernelstub configuration — reinstalando"
    kernelstub --add-options "$opt" 2>&1 || echo "  ERRO ao reinstalar $opt"
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

if [ "$reload_systemd" -eq 1 ]; then
  echo "  systemctl daemon-reload"
  systemctl daemon-reload
  systemctl enable --now ritual-aurora-root.service >/dev/null 2>&1 || true
  systemctl enable --now ritual-aurora-self-heal.timer >/dev/null 2>&1 || true
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

# Kernel params via kernelstub (System76 não mexe normalmente, mas garantimos)
ensure_kernel_option "pcie_aspm=off"
ensure_kernel_option "mitigations=off"
ensure_kernel_option "threadirqs"

# Aplicar sysctl (idempotente)
sysctl --system >/dev/null 2>&1 || true

echo "  OK"
