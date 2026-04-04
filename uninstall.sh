#!/usr/bin/env bash
# uninstall.sh — Desinstalador do Andromeda-OS
# Uso: bash uninstall.sh [--dry-run] [--force]

set -euo pipefail

ZDOTDIR_TARGET="${HOME}/.config/zsh"
DRY_RUN=false
FORCE=false
MANIFEST_DIR="${HOME}/.local/share/andromeda"
MANIFEST_FILE="${MANIFEST_DIR}/install-manifest.json"

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --force)   FORCE=true ;;
    esac
done

# --- Paleta Dracula para whiptail (NEWT_COLORS) ---
export NEWT_COLORS='
root=white,black
window=white,black
border=lightcyan,black
shadow=black,black
title=white,black
button=black,white
actbutton=black,lightcyan
checkbox=white,black
actcheckbox=black,lightcyan
entry=white,black
label=white,black
listbox=white,black
actlistbox=black,lightcyan
textbox=white,black
acttextbox=lightcyan,black
helpline=white,black
roottext=lightcyan,black
emptyscale=black,black
fullscale=lightcyan,black
disentry=cyan,black
compactbutton=white,black
actsellistbox=black,lightcyan
sellistbox=lightcyan,black
'

# --- Utilitários ---
_run() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

_C_PURPLE='\033[0;35m'
_C_GREEN='\033[0;32m'
_C_YELLOW='\033[0;33m'
_C_RED='\033[0;31m'
_C_CYAN='\033[0;36m'
_C_DIM='\033[2m'
_C_BOLD='\033[1m'
_C_RESET='\033[0m'

_info()  { echo -e "  ${_C_CYAN}>>${_C_RESET} $*"; }
_ok()    { echo -e "  ${_C_GREEN}OK${_C_RESET}  $*"; }
_warn()  { echo -e "  ${_C_YELLOW}!!${_C_RESET} $*" >&2; }
_err()   { echo -e "  ${_C_RED}ERRO${_C_RESET} $*" >&2; }

CURRENT_STEP=0
TOTAL_STEPS=0
REMOVED_ITEMS=()

_step() {
    ((++CURRENT_STEP))
    local desc="$1"
    echo ""
    echo -e "  ${_C_PURPLE}${_C_BOLD}[${CURRENT_STEP}/${TOTAL_STEPS}]${_C_RESET} ${desc}"
    echo -e "  ${_C_DIM}$(printf '%.0s─' {1..48})${_C_RESET}"
}

# --- TUI ---
_tui_available() {
    command -v whiptail &>/dev/null && echo "whiptail" && return
    command -v dialog   &>/dev/null && echo "dialog"   && return
    echo "plain"
}

_tui() { _tui_available; }

_yesno() {
    local title="$1" question="$2" defaultno="${3:-}"
    local tui extra_flags=""
    tui=$(_tui)

    [[ "$defaultno" == "defaultno" ]] && extra_flags="--defaultno"

    case "$tui" in
        whiptail|dialog)
            "$tui" --title "$title" --backtitle "Andromeda-OS :: Desinstalador" \
                $extra_flags --yesno "$question" 10 65 3>&1 1>&2 2>&3
            return $?
            ;;
        plain)
            local hint="s/N"
            [[ -z "$defaultno" ]] && hint="S/n"
            printf "  %s (%s): " "$question" "$hint" >&2
            local val
            read -r val
            if [[ -n "$defaultno" ]]; then
                [[ "$val" == "s" || "$val" == "S" || "$val" == "y" || "$val" == "Y" ]]
            else
                [[ -z "$val" || "$val" == "s" || "$val" == "S" || "$val" == "y" || "$val" == "Y" ]]
            fi
            return $?
            ;;
    esac
}

_msgbox() {
    local title="$1" msg="$2"
    local tui
    tui=$(_tui)

    case "$tui" in
        whiptail|dialog)
            "$tui" --title "$title" --backtitle "Andromeda-OS :: Desinstalador" --msgbox "$msg" 20 70
            ;;
        plain)
            echo ""
            echo "  === $title ==="
            echo "$msg"
            echo ""
            ;;
    esac
}

_checklist() {
    local title="$1"; shift
    local question="$1"; shift
    local tui
    tui=$(_tui)

    case "$tui" in
        whiptail|dialog)
            "$tui" --title "$title" --backtitle "Andromeda-OS :: Desinstalador" \
                --cancel-button "Cancelar" \
                --checklist "$question" 22 70 12 "$@" 3>&1 1>&2 2>&3 || return 1
            ;;
        plain)
            echo "  $question" >&2
            local result=""
            while [[ $# -ge 3 ]]; do
                local tag="$1" desc="$2" state="$3"
                shift 3
                local default_hint
                if [[ "$state" == "on" ]]; then default_hint="S/n"; else default_hint="s/N"; fi
                printf "  [%s] %s (%s): " "$tag" "$desc" "$default_hint" >&2
                local val
                read -r val
                if [[ "$state" == "on" ]]; then
                    if [[ -z "$val" || "$val" == "s" || "$val" == "S" ]]; then
                        result="$result \"$tag\""
                    fi
                else
                    if [[ "$val" == "s" || "$val" == "S" ]]; then
                        result="$result \"$tag\""
                    fi
                fi
            done
            echo "$result"
            ;;
    esac
}

# --- Backup de segurança ---
_backup_configs() {
    local backup_dir="$HOME/.config/andromeda-backup.$(date +%Y%m%d_%H%M%S)"
    local backed_up=false

    for f in config.local.zsh .zsh_secrets profiles.yml; do
        if [[ -f "$ZDOTDIR_TARGET/$f" ]]; then
            if [[ "$backed_up" == false ]]; then
                _run mkdir -p "$backup_dir"
                backed_up=true
            fi
            _run cp "$ZDOTDIR_TARGET/$f" "$backup_dir/"
        fi
    done

    if [[ -f "$ZDOTDIR_TARGET/vault/secrets.gpg" ]]; then
        if [[ "$backed_up" == false ]]; then
            _run mkdir -p "$backup_dir"
            backed_up=true
        fi
        _run cp "$ZDOTDIR_TARGET/vault/secrets.gpg" "$backup_dir/"
    fi

    if [[ "$backed_up" == true ]]; then
        _ok "Backup de seguranca salvo em: $backup_dir"
    else
        _ok "Nenhum arquivo sensivel para backup"
    fi
}

# --- Etapas de desinstalação ---

_uninstall_zdotdir() {
    _step "Removendo ZDOTDIR do ~/.zshenv"
    local zshenv="$HOME/.zshenv"

    if [[ -f "$zshenv" ]] && grep -qF "ZDOTDIR" "$zshenv"; then
        _run sed -i '/ZDOTDIR/d' "$zshenv"
        if [[ -f "$zshenv" ]] && [[ ! -s "$zshenv" ]]; then
            _run rm -f "$zshenv"
            _ok "~/.zshenv removido (estava vazio)"
        else
            _ok "ZDOTDIR removido do ~/.zshenv"
        fi
        REMOVED_ITEMS+=("ZDOTDIR")
    else
        _ok "ZDOTDIR nao estava em ~/.zshenv"
    fi
}

_uninstall_omz() {
    _step "Removendo Oh My Zsh"
    local omz_dir="$ZDOTDIR_TARGET/.oh-my-zsh"

    if [[ -d "$omz_dir" ]]; then
        _run rm -rf "$omz_dir"
        _ok "Oh My Zsh removido"
        REMOVED_ITEMS+=("Oh My Zsh + plugins")
    else
        _ok "Oh My Zsh nao encontrado"
    fi
}

_uninstall_hooks() {
    _step "Removendo hooks git globais"
    local hooks_dest="$HOME/.config/git/hooks"
    local template_dest="$HOME/.config/git/commit-template"

    if [[ -d "$hooks_dest" ]]; then
        _run rm -rf "$hooks_dest"
        _ok "Hooks removidos de $hooks_dest"
        REMOVED_ITEMS+=("Git Hooks")
    else
        _ok "Hooks nao encontrados"
    fi

    if [[ -f "$template_dest" ]]; then
        _run rm -f "$template_dest"
        _ok "Commit template removido"
    fi

    if git config --global core.hooksPath &>/dev/null; then
        _run git config --global --unset core.hooksPath
        _ok "core.hooksPath removido do gitconfig"
    fi

    if git config --global commit.template &>/dev/null; then
        _run git config --global --unset commit.template
        _ok "commit.template removido do gitconfig"
    fi
}

_uninstall_ritual() {
    _step "Removendo Ritual da Aurora"

    local autostart="$HOME/.config/autostart/ritual_aurora.desktop"
    local service="/etc/systemd/system/ritual-aurora-root.service"

    if [[ -f "$autostart" ]]; then
        _run rm -f "$autostart"
        _ok "Autostart removido"
        REMOVED_ITEMS+=("Ritual da Aurora (autostart)")
    else
        _ok "Autostart nao encontrado"
    fi

    if [[ -f "$service" ]]; then
        _info "Desabilitando systemd service (requer sudo)..."
        _run sudo systemctl disable ritual-aurora-root 2>/dev/null || true
        _run sudo rm -f "$service"
        _run sudo systemctl daemon-reload
        _ok "Systemd service removido"
        REMOVED_ITEMS+=("Ritual da Aurora (systemd)")
    else
        _ok "Systemd service nao encontrado"
    fi
}

_uninstall_atalhos() {
    _step "Removendo atalhos COSMIC DE"

    local comp_kb="$HOME/.config/cosmic/com.system76.CosmicComp/v1/custom_keybindings"
    local term_kb="$HOME/.config/cosmic/com.system76.CosmicTerm/v1/keybindings"

    if [[ -f "$comp_kb" ]]; then
        _run rm -f "$comp_kb"
        _ok "Atalhos do compositor removidos"
        REMOVED_ITEMS+=("Atalhos COSMIC (compositor)")
    else
        _ok "Atalhos do compositor nao encontrados"
    fi

    if [[ -f "$term_kb" ]]; then
        _run rm -f "$term_kb"
        _ok "Atalhos do terminal removidos"
        REMOVED_ITEMS+=("Atalhos COSMIC (terminal)")
    else
        _ok "Atalhos do terminal nao encontrados"
    fi
}

_uninstall_symlink() {
    _step "Removendo symlink"

    local dev_dir="${DEV_DIR:-$HOME/Desenvolvimento}"
    local link_path="$dev_dir/Andromeda-OS"

    if [[ -L "$link_path" ]]; then
        _run rm -f "$link_path"
        _ok "Symlink removido: $link_path"
        REMOVED_ITEMS+=("Symlink")
    else
        _ok "Symlink nao encontrado (ou e um diretorio real)"
    fi
}

_uninstall_shell() {
    _step "Revertendo shell padrao"

    local zsh_path
    zsh_path=$(command -v zsh 2>/dev/null || echo "/bin/zsh")
    local bash_path
    bash_path=$(command -v bash 2>/dev/null || echo "/bin/bash")

    if [[ "$SHELL" == "$zsh_path" ]]; then
        _info "Shell atual: zsh"
        if _yesno "Shell" "Reverter shell padrao para bash ($bash_path)?"; then
            _run chsh -s "$bash_path"
            _ok "Shell revertido para bash"
            REMOVED_ITEMS+=("Shell (revertido para bash)")
        else
            _ok "Shell mantido como zsh"
        fi
    else
        _ok "Shell ja nao e zsh"
    fi
}

_uninstall_configs() {
    _step "Removendo configuracoes locais"

    local configs_removed=false

    for f in config.local.zsh .zsh_secrets profiles.yml; do
        if [[ -f "$ZDOTDIR_TARGET/$f" ]]; then
            _run rm -f "$ZDOTDIR_TARGET/$f"
            _ok "$f removido"
            configs_removed=true
        fi
    done

    if [[ "$configs_removed" == true ]]; then
        REMOVED_ITEMS+=("Configs locais")
    else
        _ok "Nenhuma config local encontrada"
    fi
}

_uninstall_andromeda() {
    _step "Removendo Andromeda-OS completo"

    if [[ -d "$ZDOTDIR_TARGET" ]]; then
        _run rm -rf "$ZDOTDIR_TARGET"
        _ok "~/.config/zsh/ removido completamente"
        REMOVED_ITEMS+=("Andromeda-OS (~/.config/zsh/)")
    else
        _ok "~/.config/zsh/ nao encontrado"
    fi

    if [[ -f "$MANIFEST_FILE" ]]; then
        _run rm -f "$MANIFEST_FILE"
        _ok "Manifesto de instalacao removido"
    fi
}

# --- Main ---
main() {
    local start_time=$SECONDS

    echo ""
    echo -e "  ${_C_RED}${_C_BOLD}"
    echo '    _              _                               _       '
    echo '   / \   _ __   __| |_ __ ___  _ __ ___   ___  __| | __ _ '
    echo '  / _ \ |  _ \ / _` |  __/ _ \|  _ ` _ \ / _ \/ _` |/ _` |'
    echo ' / ___ \| | | | (_| | | | (_) | | | | | |  __/ (_| | (_| |'
    echo '/_/   \_\_| |_|\__,_|_|  \___/|_| |_| |_|\___|\__,_|\__,_|'
    echo '                                              DESINSTALAR'
    echo -e "  ${_C_RESET}"
    echo -e "  ${_C_DIM}  Desinstalador do Andromeda-OS${_C_RESET}"
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${_C_YELLOW}  MODO: dry-run (nenhuma alteracao sera feita)${_C_RESET}"
    fi

    if [[ ! -d "$ZDOTDIR_TARGET" ]]; then
        _warn "Andromeda-OS nao encontrado em $ZDOTDIR_TARGET"
        _warn "Nada para desinstalar."
        exit 0
    fi

    # Confirmacao inicial
    if [[ "$FORCE" != true ]]; then
        _msgbox "Desinstalador Andromeda-OS" \
"Este script remove componentes instalados pelo install.sh.

  - NUNCA remove pacotes do sistema (zsh, fzf, git, etc.)
  - Faz backup automatico de configs sensiveis
  - Cada componente pode ser selecionado individualmente

Pressione OK para escolher o que remover."
    fi

    # Checklist de componentes
    local components=""
    if [[ "$FORCE" == true ]]; then
        components='"zdotdir" "omz" "hooks" "ritual" "atalhos" "symlink" "shell" "configs" "andromeda"'
    else
        components=$(_checklist "Componentes" "Selecione o que desinstalar:" \
            "zdotdir"   "ZDOTDIR do ~/.zshenv"              "on" \
            "omz"       "Oh My Zsh + plugins"               "on" \
            "hooks"     "Hooks git globais"                  "on" \
            "ritual"    "Ritual da Aurora (GPU)"             "on" \
            "atalhos"   "Atalhos COSMIC DE"                  "on" \
            "symlink"   "Symlink ~/Desenvolvimento/"         "on" \
            "shell"     "Reverter shell para bash"           "off" \
            "configs"   "Configs locais (secrets, profiles)" "off" \
            "andromeda" "Remover ~/.config/zsh/ COMPLETO"    "off") || {
            echo ""
            _info "Desinstalacao cancelada."
            exit 0
        }
    fi

    if [[ -z "$components" ]]; then
        echo ""
        _info "Nenhum componente selecionado. Nada a fazer."
        exit 0
    fi

    # Confirmacao final
    if [[ "$FORCE" != true ]]; then
        if ! _yesno "Confirmar" "Prosseguir com a desinstalacao dos componentes selecionados?" "defaultno"; then
            _info "Desinstalacao cancelada."
            exit 0
        fi
    fi

    # Contar etapas selecionadas
    for tag in zdotdir omz hooks ritual atalhos symlink shell configs andromeda; do
        if echo "$components" | grep -qw "$tag"; then
            ((TOTAL_STEPS++))
        fi
    done
    ((TOTAL_STEPS++))  # +1 para etapa de backup

    # Backup de segurança (sempre, antes de qualquer remocao)
    _step "Backup de seguranca"
    _backup_configs

    # Executar etapas selecionadas
    echo "$components" | grep -qw "zdotdir"   && _uninstall_zdotdir
    echo "$components" | grep -qw "omz"       && _uninstall_omz
    echo "$components" | grep -qw "hooks"     && _uninstall_hooks
    echo "$components" | grep -qw "ritual"    && _uninstall_ritual
    echo "$components" | grep -qw "atalhos"   && _uninstall_atalhos
    echo "$components" | grep -qw "symlink"   && _uninstall_symlink
    echo "$components" | grep -qw "shell"     && _uninstall_shell
    echo "$components" | grep -qw "configs"   && _uninstall_configs
    echo "$components" | grep -qw "andromeda" && _uninstall_andromeda

    # Resumo
    echo ""
    echo -e "  ${_C_DIM}$(printf '%.0s─' {1..48})${_C_RESET}"
    echo ""

    if [[ ${#REMOVED_ITEMS[@]} -eq 0 ]]; then
        echo -e "  ${_C_YELLOW}Nenhum componente foi removido.${_C_RESET}"
    else
        echo -e "  ${_C_RED}${_C_BOLD}Componentes removidos:${_C_RESET}"
        for item in "${REMOVED_ITEMS[@]}"; do
            echo -e "    ${_C_RED}-${_C_RESET} $item"
        done
    fi

    echo ""
    echo -e "  ${_C_DIM}Pacotes do sistema (zsh, fzf, fastfetch, earlyoom, etc.)${_C_RESET}"
    echo -e "  ${_C_DIM}nao foram removidos. Use 'sudo apt remove' se desejar.${_C_RESET}"

    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo -e "  ${_C_YELLOW}Nenhuma alteracao foi feita (dry-run).${_C_RESET}"
    fi

    local elapsed=$(( SECONDS - start_time ))
    echo ""
    echo -e "  ${_C_PURPLE}${_C_BOLD}Desinstalacao concluida.${_C_RESET}"
    echo -e "  ${_C_DIM}Tempo total: ${elapsed}s${_C_RESET}"
    echo ""
}

main "$@"

# "A liberdade e o direito de fazer tudo o que as leis permitem." — Montesquieu
