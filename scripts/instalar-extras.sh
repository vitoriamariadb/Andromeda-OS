#!/usr/bin/env bash
# instalar-extras.sh — Pacotes extras para o ambiente COSMIC DE
# Chamado por _step_extras() no install.sh
# Executável standalone: bash scripts/instalar-extras.sh

set -euo pipefail

_ok()   { echo "  OK  $*"; }
_info() { echo "  >>  $*"; }
_warn() { echo "  !!  $*" >&2; }

# --- earlyoom: protetor de memória (OOM killer inteligente) ---
if systemctl is-active --quiet earlyoom 2>/dev/null; then
    _ok "earlyoom já ativo"
elif command -v earlyoom &>/dev/null; then
    _info "earlyoom instalado, habilitando serviço..."
    sudo systemctl enable --now earlyoom
    _ok "earlyoom habilitado"
else
    _info "Instalando earlyoom..."
    sudo apt-get install -y earlyoom
    sudo systemctl enable --now earlyoom
    _ok "earlyoom instalado e habilitado"
fi

# --- Gradia: ferramenta de screenshot com anotações (Flatpak) ---
if flatpak list 2>/dev/null | grep -q "be.alexandervanhee.gradia"; then
    _ok "Gradia já instalado"
elif command -v flatpak &>/dev/null; then
    _info "Instalando Gradia via Flatpak..."
    # Garantir que flathub está configurado
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    if flatpak install -y flathub be.alexandervanhee.gradia; then
        _ok "Gradia instalado"
    else
        _warn "Falha ao instalar Gradia — instale manualmente:"
        _warn "  flatpak install flathub be.alexandervanhee.gradia"
    fi
else
    _warn "Flatpak não disponível — instale manualmente:"
    _warn "  sudo apt install flatpak"
    _warn "  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
    _warn "  flatpak install flathub be.alexandervanhee.gradia"
fi
