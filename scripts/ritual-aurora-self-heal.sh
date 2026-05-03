#!/usr/bin/env bash
# Reinstala arquivos do Ritual da Aurora a partir das cópias-fonte em
# ~/.config/zsh/scripts/. Idempotente. Roda diariamente via timer
# (e 2min pós-boot) para sobreviver a updates da System76.
#
# v2: cobre gamemode.ini, ritual-aurora-clipboard-trim.{sh,service,timer}
#     e os kernel params mitigations=off + threadirqs (além de pcie_aspm=off).
# v3: cobre OpenRGB Gloway (udev, modules-load, systemd service com ExecStop
#     pra que Windows não acorde com Flashing) + acpi_enforce_resources=lax.
# v3.3: cobre AHCI link power + xHCI PCI runtime PM (vetor system76-power
#     daemon setando med_power_with_dipm que matava charging USB e enumeração
#     de pendrives). Adiciona validate_power_state() pra reparo em runtime
#     e audit_bios_state() pra reportar drift de tunings BIOS-only (ReBAR,
#     RAM speed, WHEA).
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
echo "$(date -Iseconds) — self-heal run (v3.3)"

if [ ! -d "$SRC" ]; then
  echo "  ERRO: $SRC não existe. Abortando."
  exit 1
fi

reload_systemd=0
reload_udev=0
restart_earlyoom=0
restart_openrgb=0
restart_root_service=0
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
      root_service) reload_systemd=1; restart_root_service=1 ;;
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
install_if_diff "$SRC/ritual-aurora-root.service"          /etc/systemd/system/ritual-aurora-root.service     644 root_service
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

# v3.3: nova udev rule pra storage AHCI link PM + xHCI PCI runtime PM
install_if_diff "$SRC/99-storage-no-link-pm.rules"         /etc/udev/rules.d/99-storage-no-link-pm.rules           644 udev

# v3.3: script de reparo de storage PM (chamado pelo drop-in do system76-power
# como ExecStartPost — necessário porque o daemon escreve direto via sysfs e
# não dispara evento udev; udev rule sozinha não cobre re-aplicação após restart)
install_if_diff "$SRC/restore-storage-pm.sh"               /usr/local/bin/restore-storage-pm.sh                    755 none

# v3.3: drop-in pro com.system76.PowerDaemon.service (ExecStartPost de reparo)
install_if_diff "$SRC/system76-power-restore-storage-pm.conf" /etc/systemd/system/com.system76.PowerDaemon.service.d/99-restore-storage-pm.conf 644 systemd

# v3.3: healthcheck unificado (idempotente, sem sudo, prinata estado de TUDO)
install_if_diff "$SRC/overclock-healthcheck.sh"            /usr/local/bin/overclock-healthcheck.sh                 755 none

if [ "$reload_systemd" -eq 1 ]; then
  echo "  systemctl daemon-reload"
  systemctl daemon-reload
  systemctl enable --now ritual-aurora-root.service >/dev/null 2>&1 || true
  systemctl enable --now ritual-aurora-self-heal.timer >/dev/null 2>&1 || true
  systemctl enable --now openrgb-gloway.service >/dev/null 2>&1 || true
fi
if [ "$restart_root_service" -eq 1 ]; then
  echo "  systemctl restart ritual-aurora-root.service (config mudou)"
  systemctl restart ritual-aurora-root.service 2>&1 || err "restart ritual-aurora-root falhou"
fi
if [ "$reload_udev" -eq 1 ]; then
  echo "  udevadm reload + trigger"
  udevadm control --reload
  udevadm trigger --subsystem-match=usb --action=add
  udevadm trigger --subsystem-match=i2c-dev --action=add 2>/dev/null || true
  udevadm trigger --subsystem-match=scsi_host --action=change 2>/dev/null || true
  udevadm trigger --subsystem-match=pci --action=change 2>/dev/null || true
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

# v3.3: validate_power_state — repara em runtime se algo voltou pro estado errado
# (cobre SCSI link PM, USB power/control, xHCI PCI). Esse é o ANTIDOTO ao race
# com system76-power daemon que pode re-setar med_power_with_dipm depois do nosso
# ritual-aurora-root.service rodar. Como o daemon escreve uma vez no startup, esse
# check rodando a cada 1h via timer garante que voltamos ao estado correto rapidamente.
validate_power_state() {
  local bad=0
  for f in /sys/class/scsi_host/host*/link_power_management_policy; do
    [ -r "$f" ] || continue
    local cur
    cur="$(cat "$f" 2>/dev/null || echo unknown)"
    if [ "$cur" != "max_performance" ]; then
      echo "  REPARO power: $f = $cur → max_performance"
      echo max_performance > "$f" 2>/dev/null || err "falhou escrever max_performance em $f"
      bad=$((bad+1))
    fi
  done
  for f in /sys/bus/usb/devices/*/power/control; do
    [ -r "$f" ] || continue
    local cur
    cur="$(cat "$f" 2>/dev/null || echo unknown)"
    if [ "$cur" != "on" ]; then
      echo "  REPARO power: $f = $cur → on"
      echo on > "$f" 2>/dev/null || err "falhou escrever on em $f"
      bad=$((bad+1))
    fi
  done
  for f in /sys/bus/usb/devices/*/power/autosuspend; do
    [ -r "$f" ] || continue
    local cur
    cur="$(cat "$f" 2>/dev/null || echo unknown)"
    if [ "$cur" != "-1" ]; then
      echo "  REPARO power: $f = $cur → -1"
      echo -1 > "$f" 2>/dev/null || err "falhou escrever -1 em $f"
      bad=$((bad+1))
    fi
  done
  for f in /sys/bus/pci/drivers/xhci_hcd/*/power/control; do
    [ -r "$f" ] || continue
    local cur
    cur="$(cat "$f" 2>/dev/null || echo unknown)"
    if [ "$cur" != "on" ]; then
      echo "  REPARO power: $f = $cur → on"
      echo on > "$f" 2>/dev/null || err "falhou escrever on em $f"
      bad=$((bad+1))
    fi
  done
  if [ "$bad" -eq 0 ]; then
    echo "  power-state check: OK (USB+SCSI+xHCI no estado desejado)"
  else
    echo "  power-state check: $bad correções aplicadas em runtime"
  fi
}
validate_power_state

# v3.3: audit_bios_state — apenas REPORTA drift de tunings que são BIOS-only
# (ReBAR, RAM speed, WHEA). Não tenta consertar — se drift, user precisa ir ao
# BIOS aplicar BIOS-CHECKLIST.md. Útil pra detectar limpeza de CMOS ou regressão.
audit_bios_state() {
  # ReBAR: BAR1 da RTX 4060 (0a:00.0) deve mostrar 8GB
  local bar1
  bar1="$(lspci -vv -s 0a:00.0 2>/dev/null | grep 'Region 1:' | head -1)"
  if [ -n "$bar1" ]; then
    if echo "$bar1" | grep -q '8G'; then
      echo "  bios-audit: ReBAR OK (BAR1=8GB)"
    else
      echo "  bios-audit: AVISO ReBAR drift — esperado 8GB, lspci mostra: $bar1"
    fi
  fi
  # RAM speed: deve ser 3800 MT/s (XMP Profile1)
  local ram_speed
  ram_speed="$(dmidecode -t memory 2>/dev/null | grep -E 'Configured Memory Speed' | head -1 | awk '{print $4}')"
  if [ -n "$ram_speed" ]; then
    if [ "$ram_speed" = "3800" ]; then
      echo "  bios-audit: RAM speed OK (3800 MT/s)"
    else
      echo "  bios-audit: AVISO RAM drift — esperado 3800, dmidecode mostra: ${ram_speed} MT/s"
    fi
  fi
  # WHEA / MCE pós-boot: deve ter só "In-kernel MCE decoding enabled"
  local whea_count
  whea_count="$(dmesg 2>/dev/null | grep -iE 'whea|machine check' | grep -viE 'In-kernel MCE decoding|MCE decoder' | wc -l)"
  if [ "$whea_count" -eq 0 ]; then
    echo "  bios-audit: WHEA/MCE limpo"
  else
    echo "  bios-audit: AVISO WHEA/MCE — $whea_count linhas de erro em dmesg"
  fi
}
audit_bios_state

# Defesa anti-Windows-update (silent — sai limpo se Windows não está montável)
if [ -x /usr/local/sbin/dual-boot-defender.sh ]; then
  /usr/local/sbin/dual-boot-defender.sh --silent 2>&1 || true
fi

if [ "$errors" -gt 0 ]; then
  echo "  TERMINOU COM $errors ERRO(S) — checar log acima"
  exit 1
fi

echo "  OK"
