#!/usr/bin/env bash
# restore-storage-pm.sh — força max_performance em todos scsi_host link power
# e on em xHCI PCI runtime PM e USB power/control + autosuspend=-1.
#
# Por que existe: system76-power daemon reescreve link_power_management_policy=med_power_with_dipm
# em cada (re)start, sobrescrevendo nossa udev rule (porque o daemon escreve direto via sysfs,
# não dispara evento udev). Esse script roda como ExecStartPost do daemon — então logo após
# ele setar med_power_with_dipm, nosso script corrige pra max_performance.
#
# Também roda standalone (chamado pelo self-heal a cada 1h e pelo ritual-aurora-root.service no boot).
set +e
for f in /sys/class/scsi_host/host*/link_power_management_policy; do
  [ -w "$f" ] && echo max_performance > "$f" 2>/dev/null
done
for f in /sys/bus/usb/devices/*/power/control; do
  [ -w "$f" ] && echo on > "$f" 2>/dev/null
done
for f in /sys/bus/usb/devices/*/power/autosuspend; do
  [ -w "$f" ] && echo -1 > "$f" 2>/dev/null
done
for f in /sys/bus/pci/drivers/xhci_hcd/*/power/control; do
  [ -w "$f" ] && echo on > "$f" 2>/dev/null
done
exit 0
