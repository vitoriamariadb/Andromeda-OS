#!/usr/bin/env bash
# Dual-Boot Defender — re-aplica o neutralizador do Windows após feature update.
#
# CONTEXTO: Windows feature updates podem recriar /EFI/Microsoft/Boot/bootmgfw.efi
# e re-adicionar um Boot0000 "Windows Boot Manager" no NVRAM EFI, revertendo
# nossa neutralização (rename pra .DISABLED + Boot0002 oculto).
#
# Modos:
#   bash dual-boot-defender.sh           (verbose, manual)
#   bash dual-boot-defender.sh --silent  (chamado pelo self-heal, só age se preciso)
#
# Fonte-de-verdade: ~/.config/zsh/scripts/dual-boot-defender.sh
# Doc relacionada: dual-boot-priority-2026-05-02/README.md
set -u

SILENT=0
[ "${1:-}" = "--silent" ] && SILENT=1

say() { [ "$SILENT" -eq 1 ] || printf '%s\n' "$*"; }

if [ "$(id -u)" -ne 0 ]; then
  if [ "$SILENT" -eq 1 ]; then exit 0; fi
  printf '%s\n' "Precisa sudo. Re-executando…"
  exec sudo bash "$0" "$@"
fi

WIN_EFI=/dev/sda1
MNT=/mnt/winefi-defender

if [ ! -b "$WIN_EFI" ]; then
  say "  $WIN_EFI não é block device — Windows pode estar em outro disco. Sai limpo."
  exit 0
fi

mkdir -p "$MNT"

say ">>> Montando EFI do Windows ($WIN_EFI)…"
if ! mount "$WIN_EFI" "$MNT" 2>/dev/null; then
  say "  Falha ao montar — já montado em outro lugar, ou partição diferente. Sai limpo."
  rmdir "$MNT" 2>/dev/null || true
  exit 0
fi
trap 'umount "$MNT" 2>/dev/null; rmdir "$MNT" 2>/dev/null' EXIT

BOOTDIR="$MNT/EFI/Microsoft/Boot"
if [ ! -d "$BOOTDIR" ]; then
  say "  $BOOTDIR não existe — Windows não está em $WIN_EFI. Sai limpo."
  exit 0
fi

say ">>> Estado atual:"
[ "$SILENT" -eq 1 ] || ls -la "$BOOTDIR"/bootmgfw* 2>/dev/null || true

# Caso 1: Windows recriou bootmgfw.efi (sem .DISABLED)
if [ -f "$BOOTDIR/bootmgfw.efi" ]; then
  say "!! Windows recriou bootmgfw.efi — neutralizando de novo."
  if [ -f "$BOOTDIR/bootmgfw.efi.DISABLED" ]; then
    mv -f "$BOOTDIR/bootmgfw.efi" "$BOOTDIR/bootmgfw.efi.DISABLED"
    say "  → bootmgfw.efi → bootmgfw.efi.DISABLED (substituiu)"
  else
    cp "$BOOTDIR/bootmgfw.efi" "$BOOTDIR/bootmgfw.efi.bak"
    mv "$BOOTDIR/bootmgfw.efi" "$BOOTDIR/bootmgfw.efi.DISABLED"
    say "  → backup em .bak + renomeado pra .DISABLED"
  fi
fi

# Caso 2: Windows recriou Boot0000 "Windows Boot Manager" no NVRAM
if efibootmgr -v 2>/dev/null | grep -E "^Boot[0-9A-Fa-f]+\*? Windows Boot Manager" >/dev/null; then
  WIN_ID=$(efibootmgr 2>/dev/null | grep -E "^Boot[0-9A-Fa-f]+\*? Windows Boot Manager" | head -1 | grep -oE "^Boot[0-9A-Fa-f]+" | sed 's/Boot//')
  say "!! Entry 'Windows Boot Manager' (Boot$WIN_ID) recriada — removendo."
  efibootmgr -b "$WIN_ID" -B >/dev/null 2>&1 || true
  say "  → Boot$WIN_ID deletada"
fi

# Caso 3: garantir Pop!_OS primeira no BootOrder
if efibootmgr 2>/dev/null | grep -E "^Boot0001\*? Pop!_OS" >/dev/null; then
  CURRENT_ORDER=$(efibootmgr 2>/dev/null | grep "^BootOrder:" | awk '{print $2}')
  if [ -n "$CURRENT_ORDER" ] && [[ "$CURRENT_ORDER" != 0001* ]]; then
    NEW_ORDER="0001,$(printf '%s' "$CURRENT_ORDER" | tr ',' '\n' | grep -v '^0001$' | tr '\n' ',' | sed 's/,$//')"
    say "!! Pop!_OS não estava primeira — reordenando pra: $NEW_ORDER"
    efibootmgr -o "$NEW_ORDER" >/dev/null 2>&1 || true
  fi
fi

say ">>> Defender concluído."
