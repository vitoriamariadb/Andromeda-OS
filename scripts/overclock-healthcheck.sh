#!/usr/bin/env bash
# overclock-healthcheck.sh — valida TODOS os tunings do Ritual da Aurora
#   (hardware overclock + USB/SCSI/xHCI power + RGB Gloway + BIOS-only state)
#
# Idempotente, sem sudo (usa /sys e dmesg sem privilégios; lspci/dmidecode
# tentam sudo -n e silenciam se não houver). Pode ser rodado a qualquer momento.
# Cole o output numa sessão Claude pra retomar contexto.
#
# Origem: substitui o healthcheck.sh ad-hoc da pasta ~/Área de trabalho/overclock/
#   — esta versão é fonte-de-verdade em ~/.config/zsh/scripts/, instalada em
#   /usr/local/bin/overclock-healthcheck.sh pelo ritual-aurora-self-heal v3.3.

set +e
PASS=0
FAIL=0
WARN=0

ok()   { echo "  [OK]   $*"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
warn() { echo "  [WARN] $*"; WARN=$((WARN+1)); }

echo "================================================================"
echo "OVERCLOCK HEALTHCHECK — $(date -Iseconds)"
echo "Hostname: $(hostname) | Kernel: $(uname -r)"
echo "================================================================"

echo ""
echo "── 1. KERNEL CMDLINE (kernelstub) ──"
for opt in pcie_aspm=off mitigations=off threadirqs acpi_enforce_resources=lax usbcore.autosuspend=-1 nvidia-drm.modeset=1; do
  if grep -qw "$opt" /proc/cmdline 2>/dev/null; then
    ok "kernel cmdline tem $opt"
  else
    fail "kernel cmdline FALTA $opt"
  fi
done

echo ""
echo "── 2. USB POWER (autosuspend desativado) ──"
usbcore_param="$(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)"
if [ "$usbcore_param" = "-1" ]; then
  ok "/sys/module/usbcore/parameters/autosuspend = -1"
else
  fail "/sys/module/usbcore/parameters/autosuspend = $usbcore_param (esperado -1)"
fi
usb_off=0
usb_total=0
for f in /sys/bus/usb/devices/*/power/control; do
  [ -r "$f" ] || continue
  usb_total=$((usb_total+1))
  [ "$(cat "$f" 2>/dev/null)" = "on" ] || usb_off=$((usb_off+1))
done
if [ "$usb_off" -eq 0 ]; then
  ok "$usb_total USB devices todos com power/control=on"
else
  fail "$usb_off/$usb_total USB devices NÃO estão em on"
fi

echo ""
echo "── 3. SCSI / AHCI LINK POWER (max_performance) ──"
scsi_bad=0
scsi_total=0
for f in /sys/class/scsi_host/host*/link_power_management_policy; do
  [ -r "$f" ] || continue
  scsi_total=$((scsi_total+1))
  cur="$(cat "$f" 2>/dev/null)"
  if [ "$cur" != "max_performance" ]; then
    scsi_bad=$((scsi_bad+1))
    fail "$f = $cur (esperado max_performance)"
  fi
done
if [ "$scsi_bad" -eq 0 ] && [ "$scsi_total" -gt 0 ]; then
  ok "$scsi_total SCSI hosts todos em max_performance"
fi

echo ""
echo "── 4. xHCI HOST CONTROLLERS (PCI runtime PM) ──"
xhci_bad=0
xhci_total=0
for f in /sys/bus/pci/drivers/xhci_hcd/*/power/control; do
  [ -r "$f" ] || continue
  xhci_total=$((xhci_total+1))
  cur="$(cat "$f" 2>/dev/null)"
  if [ "$cur" != "on" ]; then
    xhci_bad=$((xhci_bad+1))
    fail "$f = $cur (esperado on)"
  fi
done
if [ "$xhci_bad" -eq 0 ] && [ "$xhci_total" -gt 0 ]; then
  ok "$xhci_total xHCI controllers todos em power/control=on"
fi

echo ""
echo "── 5. SYSTEMD SERVICES ──"
for svc in ritual-aurora-root.service ritual-aurora-self-heal.timer openrgb-gloway.service earlyoom.service com.system76.PowerDaemon.service; do
  if systemctl is-active --quiet "$svc"; then
    ok "$svc ativo"
  else
    fail "$svc NÃO ativo"
  fi
done

echo ""
echo "── 6. UDEV RULES ──"
for rule in 99-usb-kill-autosuspend.rules 99-storage-no-link-pm.rules 60-openrgb.rules; do
  if [ -f "/etc/udev/rules.d/$rule" ]; then
    if cmp -s "/home/vitoriamaria/.config/zsh/scripts/$rule" "/etc/udev/rules.d/$rule" 2>/dev/null; then
      ok "/etc/udev/rules.d/$rule (idêntica à fonte)"
    else
      warn "/etc/udev/rules.d/$rule presente mas DIFERE da fonte em ~/.config/zsh/scripts/"
    fi
  else
    fail "/etc/udev/rules.d/$rule AUSENTE"
  fi
done

echo ""
echo "── 7. SMBus i2c (RGB Gloway requer FCH SMBus do PIIX4) ──"
if i2cdetect -l 2>/dev/null | grep -q -i smbus; then
  ok "SMBus visível em i2cdetect -l"
else
  fail "SMBus NÃO aparece — acpi_enforce_resources=lax pode não ter pego"
fi
if [ -x /home/vitoriamaria/.local/bin/openrgb ]; then
  if timeout 12 /home/vitoriamaria/.local/bin/openrgb --version >/dev/null 2>&1; then
    ok "openrgb binary saudável (--version OK)"
  else
    fail "openrgb binary SEGFAULT — recovery necessário"
  fi
else
  fail "openrgb binary AUSENTE em ~/.local/bin/openrgb"
fi

echo ""
echo "── 8. OPENRGB AUTOSTART (user) ──"
if [ -f /home/vitoriamaria/.config/autostart/openrgb-gloway.desktop ]; then
  ok "autostart openrgb-gloway.desktop presente"
else
  fail "autostart openrgb-gloway.desktop AUSENTE"
fi

echo ""
echo "── 9. SELF-HEAL TIMER ──"
if systemctl is-enabled --quiet ritual-aurora-self-heal.timer 2>/dev/null; then
  next="$(systemctl list-timers ritual-aurora-self-heal.timer --no-legend 2>/dev/null | awk '{print $1, $2}')"
  ok "ritual-aurora-self-heal.timer enabled (próximo: $next)"
else
  fail "ritual-aurora-self-heal.timer NÃO está enabled"
fi

echo ""
echo "── 10. BIOS-ONLY STATE (apenas reporta drift; não é reparável via Linux) ──"
# ReBAR
bar1="$(sudo -n lspci -vv -s 0a:00.0 2>/dev/null | grep 'Region 1:' | head -1)"
if [ -n "$bar1" ]; then
  if echo "$bar1" | grep -q '8G'; then
    ok "ReBAR BAR1=8GB"
  else
    warn "ReBAR drift — lspci mostra: $bar1 (esperado 8G)"
  fi
else
  warn "ReBAR check pulado (precisa sudo: sudo lspci -vv -s 0a:00.0 | grep 'Region 1')"
fi
# RAM speed
ram_speed="$(sudo -n dmidecode -t memory 2>/dev/null | grep -E 'Configured Memory Speed' | head -1 | awk '{print $4}')"
if [ -n "$ram_speed" ]; then
  if [ "$ram_speed" = "3800" ]; then
    ok "RAM Configured Memory Speed = 3800 MT/s (XMP Profile1)"
  else
    warn "RAM drift — dmidecode mostra: ${ram_speed} MT/s (esperado 3800)"
  fi
else
  warn "RAM speed check pulado (precisa sudo: sudo dmidecode -t memory)"
fi
# WHEA / MCE
whea_count="$(dmesg 2>/dev/null | grep -iE 'whea|machine check' | grep -viE 'In-kernel MCE decoding|MCE decoder' | wc -l)"
if [ "$whea_count" -eq 0 ]; then
  ok "WHEA/MCE: limpo (só boot info)"
else
  warn "WHEA/MCE: $whea_count linhas — rodar 'dmesg | grep -iE \"whea|machine check\"' pra investigar"
fi

echo ""
echo "── 11. SENSORES (snapshot) ──"
sensors 2>/dev/null | grep -E 'Tctl|Tccd|temp[1-6]:' | head -8 | sed 's/^/  /'

echo ""
echo "── 12. SELF-HEAL LAST RUN ──"
if [ -r /var/log/ritual-aurora-self-heal.log ]; then
  last="$(grep -E '^[0-9]{4}-' /var/log/ritual-aurora-self-heal.log | tail -1)"
  ok "última run: $last"
  last_status="$(tac /var/log/ritual-aurora-self-heal.log 2>/dev/null | grep -E '^\s+(OK|TERMINOU)' | head -1)"
  echo "    status: $last_status"
else
  warn "/var/log/ritual-aurora-self-heal.log não legível pelo user (precisa sudo cat)"
fi

echo ""
echo "================================================================"
echo "RESUMO: $PASS pass | $FAIL fail | $WARN warn"
echo "================================================================"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
