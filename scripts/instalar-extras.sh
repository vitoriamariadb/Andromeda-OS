#!/usr/bin/env bash
# instalar-extras.sh — Pacotes extras para o ambiente COSMIC DE
# Chamado por _step_extras() no install.sh
# Executável standalone: bash scripts/instalar-extras.sh

set -euo pipefail

_ok()   { echo "  OK  $*"; }
_info() { echo "  >>  $*"; }
_warn() { echo "  !!  $*" >&2; }

# --- fastfetch: informações do sistema na inicialização do terminal ---
# Não está no apt do Ubuntu 24.04 — instalar via .deb do GitHub Releases
if command -v fastfetch &>/dev/null; then
    _ok "fastfetch já instalado ($(fastfetch --version 2>/dev/null | head -1))"
else
    _info "Instalando fastfetch via GitHub Releases..."
    deb_url=""
    deb_url=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
        | python3 -c "import json,sys; r=json.load(sys.stdin); print([a['browser_download_url'] for a in r['assets'] if 'amd64.deb' in a['name']][0])" 2>/dev/null) || true

    if [[ -n "$deb_url" ]]; then
        tmp_deb=$(mktemp /tmp/fastfetch-XXXXXX.deb)
        if curl -sL "$deb_url" -o "$tmp_deb" && sudo apt-get install -y "$tmp_deb"; then
            rm -f "$tmp_deb"
            _ok "fastfetch instalado"
        else
            rm -f "$tmp_deb"
            _warn "Falha ao instalar fastfetch — o terminal abrirá sem o banner de sistema"
        fi
    else
        _warn "Não foi possível obter URL do fastfetch — verifique conectividade"
    fi
fi

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

# Configura thresholds mais agressivos para workloads de dev
# Default do pacote: 10% RAM livre — tarde demais para IDEs/containers/data science
earlyoom_conf="/etc/default/earlyoom"
if ! grep -q -- "^EARLYOOM_ARGS.*-m 5" "$earlyoom_conf" 2>/dev/null; then
    _info "Configurando earlyoom (threshold 5% RAM / 10% swap)..."
    echo 'EARLYOOM_ARGS="-m 5 -s 10 -r 3600"' | sudo tee "$earlyoom_conf" > /dev/null
    sudo systemctl restart earlyoom
    _ok "earlyoom configurado com thresholds de dev"
else
    _ok "earlyoom ja configurado"
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
