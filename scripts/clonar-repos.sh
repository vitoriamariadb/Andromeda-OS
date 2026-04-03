#!/usr/bin/env bash
# clonar-repos.sh — Clona/atualiza todos os repos pessoais do GitHub em ~/Desenvolvimento/
# Chamado por _step_clonar_repos() no install.sh
# Executável standalone: bash scripts/clonar-repos.sh
#
# Requisitos: gh CLI autenticado, jq instalado, SSH alias github.com-personal configurado

set -euo pipefail

_ok()   { echo "  OK  $*"; }
_info() { echo "  >>  $*"; }
_warn() { echo "  !!  $*" >&2; }

# Repos a ignorar — gerenciados por outros mecanismos
IGNORAR=(
    "Andromeda-OS"    # gerenciado como ~/.config/zsh (ZDOTDIR)
    "[REDACTED]"  # repo de perfil GitHub, sem código
)

DEV_DIR="${DEV_DIR:-$HOME/Desenvolvimento}"

# --- Pré-verificações ---
if ! command -v gh &>/dev/null; then
    _warn "gh CLI não instalado — pulando clonagem de repos"
    _info "Para instalar: sudo apt install gh && gh auth login"
    exit 0
fi

if ! gh auth status &>/dev/null 2>&1; then
    _warn "gh CLI não autenticado — execute: gh auth login"
    exit 0
fi

if ! command -v jq &>/dev/null; then
    _warn "jq não instalado — pulando clonagem de repos"
    exit 0
fi

[[ -d "$DEV_DIR" ]] || mkdir -p "$DEV_DIR"

# --- Listar repos ---
_info "Listando repos de [REDACTED]..."
repos_json=$(gh repo list [REDACTED] --json name,sshUrl --limit 100 2>/dev/null) || {
    _warn "Falha ao listar repos — verifique autenticação do gh"
    exit 0
}

total=$(echo "$repos_json" | jq 'length')
_info "$total repos encontrados"

# --- Clonar/atualizar ---
while IFS= read -r entry; do
    name=$(echo "$entry" | jq -r '.name')
    ssh_url=$(echo "$entry" | jq -r '.sshUrl')

    # Verificar lista de ignorados
    skip=false
    for ignorado in "${IGNORAR[@]}"; do
        [[ "$name" == "$ignorado" ]] && skip=true && break
    done
    if $skip; then
        _info "Pulando: $name"
        continue
    fi

    # Substituir host padrão pelo alias SSH configurado em ~/.ssh/config
    url="${ssh_url/git@github.com:/git@github.com-personal:}"
    dest="$DEV_DIR/$name"

    if [[ -d "$dest/.git" ]]; then
        _info "Atualizando: $name"
        if git -C "$dest" pull --rebase --autostash 2>/dev/null; then
            _ok "$name atualizado"
        else
            _warn "$name: falha no pull — verifique manualmente em $dest"
        fi
    else
        _info "Clonando: $name"
        if git clone "$url" "$dest" 2>/dev/null; then
            _ok "$name clonado em $dest"
        else
            _warn "$name: falha no clone (URL: $url)"
        fi
    fi
done < <(echo "$repos_json" | jq -c '.[]')

_ok "Sincronização de repos concluída"
