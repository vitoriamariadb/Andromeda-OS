#!/usr/bin/env bash
# configurar-atalhos-cosmic.sh — Configura atalhos de teclado no COSMIC DE
# Chamado por _step_atalhos() no install.sh
# Executável standalone: bash scripts/configurar-atalhos-cosmic.sh
#
# Atalhos configurados:
#   Ctrl+Shift+T  → Abrir COSMIC Terminal
#   Alt+PrintScr  → Gradia (ferramenta de screenshot com anotações)
#   Ctrl+V        → Colar no COSMIC Terminal (sem precisar de Shift)
#   Ctrl+Shift+V  → Colar no COSMIC Terminal (padrão Linux)

set -euo pipefail

_ok()   { echo "  OK  $*"; }
_info() { echo "  >>  $*"; }
_warn() { echo "  !!  $*" >&2; }

# Verificar que estamos no COSMIC DE
DE="${XDG_CURRENT_DESKTOP:-}"
if [[ "$DE" != *"COSMIC"* ]]; then
    _warn "Desktop não é COSMIC (detectado: ${DE:-desconhecido}) — pulando atalhos"
    exit 0
fi

COSMIC_COMP_DIR="$HOME/.config/cosmic/com.system76.CosmicComp/v1"
COSMIC_TERM_DIR="$HOME/.config/cosmic/com.system76.CosmicTerm/v1"

mkdir -p "$COSMIC_COMP_DIR"
mkdir -p "$COSMIC_TERM_DIR"

# -------------------------------------------------------------------
# Atalhos do compositor (abrir apps, etc.)
# Formato: RON (Rust Object Notation) — padrão do COSMIC DE
# Arquivo: custom_keybindings em com.system76.CosmicComp/v1/
# -------------------------------------------------------------------
COMP_KEYBINDINGS="$COSMIC_COMP_DIR/custom_keybindings"

if [[ -f "$COMP_KEYBINDINGS" ]]; then
    _ok "custom_keybindings já existe — preservado (edite manualmente se necessário)"
    _info "Localização: $COMP_KEYBINDINGS"
else
    _info "Criando custom_keybindings do compositor..."
    cat > "$COMP_KEYBINDINGS" << 'RON'
[
    (
        action: Spawn("cosmic-term"),
        binding: (
            modifiers: [Ctrl, Shift],
            key: t,
        ),
        description: "Abrir terminal",
    ),
    (
        action: Spawn("flatpak run be.alexandervanhee.gradia"),
        binding: (
            modifiers: [Alt],
            key: Print,
        ),
        description: "Screenshot com anotacoes (Gradia)",
    ),
]
RON
    _ok "Atalhos do compositor configurados"
    _info "  Ctrl+Shift+T  → COSMIC Terminal"
    _info "  Alt+PrintScr  → Gradia"
    _info "Reinicie a sessão para aplicar (logout/login)"
fi

# -------------------------------------------------------------------
# Atalhos internos do COSMIC Terminal
# Ctrl+V = colar (padrão Linux é Ctrl+Shift+V)
# Formato: RON — padrão do COSMIC DE
# Arquivo: keybindings em com.system76.CosmicTerm/v1/
# -------------------------------------------------------------------
TERM_KEYBINDINGS="$COSMIC_TERM_DIR/keybindings"

if [[ -f "$TERM_KEYBINDINGS" ]]; then
    _ok "keybindings do terminal já existe — preservado"
    _info "Localização: $TERM_KEYBINDINGS"
else
    _info "Configurando Ctrl+V e Ctrl+Shift+V = colar no COSMIC Terminal..."
    cat > "$TERM_KEYBINDINGS" << 'RON'
{
    custom: [
        (
            action: Paste,
            binding: (
                modifiers: [Ctrl],
                key: v,
            ),
        ),
        (
            action: Paste,
            binding: (
                modifiers: [Ctrl, Shift],
                key: v,
            ),
        ),
    ],
}
RON
    _ok "Ctrl+V e Ctrl+Shift+V configurados como colar no terminal"
    _info "Reinicie o terminal para aplicar"
fi

# -------------------------------------------------------------------
# Nota sobre o formato RON
# -------------------------------------------------------------------
# Se os atalhos não funcionarem após reiniciar a sessão, configure
# manualmente via:
#   COSMIC Settings > Teclado > Atalhos de teclado > Atalhos customizados
#
# Os arquivos gerados aqui ficam em:
#   $HOME/.config/cosmic/com.system76.CosmicComp/v1/custom_keybindings
#   $HOME/.config/cosmic/com.system76.CosmicTerm/v1/keybindings
