<div align="center">

[![opensource](https://badges.frapsoft.com/os/v1/open-source.png?v=103)](#)
[![Licença](https://img.shields.io/badge/licença-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Zsh](https://img.shields.io/badge/shell-zsh-green.svg)](https://www.zsh.org/)
[![Oh My Zsh](https://img.shields.io/badge/Oh%20My%20Zsh-compatible-blue.svg)](https://ohmyz.sh/)

<h1>Andromeda OS</h1>

</div>

---

Configuração zsh modular e portável para Pop!\_OS 24.04 + COSMIC DE. 27 módulos de funções, 10 scripts bash, 8 scripts Python, menu FZF interativo para projetos dbt/BigQuery, controle automático de identidade git por diretório e integração com Oh My Zsh. Formatou o PC — clone o repo e rode `./install.sh`. O resto é automático.

---

### O que o instalador faz (20 etapas)

| Etapa | O que configura |
|-------|----------------|
| Deploy | Clona Andromeda-OS para `~/.config/zsh/` (ZDOTDIR) e cria symlink em `~/Desenvolvimento/` |
| Deps | `zsh fzf git jq pv rsync tree python3 pip3 whiptail dos2unix fastfetch` |
| Extras | `earlyoom` (proteção OOM) + Gradia (screenshot via Flatpak) |
| SSH | Gera `id_ed25519_personal` se não existir, configura `~/.ssh/config` com `AddKeysToAgent yes` |
| Fontes | Fontes de compatibilidade Office/LibreOffice |
| Encoding | `dos2unix` para conversão CRLF |
| Oh My Zsh | OMZ + plugins autosuggestions, syntax-highlighting, history-substring-search |
| TUI | Identidade git, caminhos, perfil profissional, sync remoto |
| Config | Gera `config.local.zsh` com os valores da TUI |
| Templates | Cria `.zsh_secrets` e `profiles.yml` a partir dos templates |
| Vault | Restaura credentials do vault GPG criptografado (opcional) |
| Hooks | Hooks git globais: `pre-commit`, `commit-msg`, `pre-push` |
| Aurora | Script de inicialização GPU (nvidia-settings + system76-power via systemd) |
| Atalhos | Atalhos COSMIC DE: `Ctrl+Shift+T` (terminal), `Alt+PrintScr` (Gradia), `Ctrl+V` (colar) |
| Repos | Clona todos os repos pessoais do GitHub em `~/Desenvolvimento/` |
| ZDOTDIR | Configura `~/.zshenv` para apontar para `~/.config/zsh/` |
| Shell | Troca shell padrão para `zsh` |
| Validação | Verifica estrutura e dependências instaladas |
| Manifesto | Captura estado inicial do sistema (opcional) |
| Resumo | Exibe comandos disponíveis e pendências manuais |

---

### Instalação

#### Bootstrap completo (nova máquina)

```bash
git clone git@github.com-personal:<seu-usuario>/Andromeda-OS.git ~/Desenvolvimento/Andromeda-OS
bash ~/Desenvolvimento/Andromeda-OS/install.sh
```

Se ainda não tiver SSH configurado, use HTTPS na primeira vez:

```bash
git clone https://github.com/<seu-usuario>/Andromeda-OS.git ~/Desenvolvimento/Andromeda-OS
bash ~/Desenvolvimento/Andromeda-OS/install.sh
# O install.sh gera a chave SSH e instrui a adicioná-la ao GitHub
```

#### Atualizar (já instalado)

```bash
cd ~/Desenvolvimento/Andromeda-OS && git pull && ./install.sh --update
```

O modo `--update` preserva `config.local.zsh`, `.zsh_secrets` e `profiles.yml` existentes.

#### Dry run (sem alterar nada)

```bash
./install.sh --dry-run
```

#### Desinstalar

```bash
bash ~/.config/zsh/uninstall.sh
```

O desinstalador é interativo (TUI whiptail) e permite selecionar quais componentes remover. Faz backup automático de configs sensíveis antes de qualquer remoção.

```bash
# Dry run (ver o que seria removido)
bash uninstall.sh --dry-run

# Remover tudo sem confirmação
bash uninstall.sh --force
```

> Pacotes do sistema (zsh, fzf, fastfetch, earlyoom) nunca são removidos pelo desinstalador.

---

### Requisitos

**Sistema (instalados automaticamente):**

```
zsh  git  fzf  jq  pv  rsync  tree  python3  pip3  whiptail  dos2unix  fastfetch
earlyoom  flatpak  gh (GitHub CLI)
```

**Python (via requirements.txt):**

```
pandas >= 2.0
openpyxl >= 3.1
tabulate >= 0.9
```

**Flatpak:**

```
be.alexandervanhee.gradia  (Gradia — screenshot com anotações)
```

**Pré-requisito externo (gh CLI):**

```bash
sudo apt install gh && gh auth login
```

---

### Módulos zsh (27)

| Módulo | Descrição |
|--------|-----------|
| `_helpers.zsh` | Paleta Dracula + utilitários base (cores, formatação) |
| `andromeda-sync.zsh` | Sincronização bidirecional do Andromeda-OS (pull ao abrir, push ao fechar) |
| `arvore.zsh` | Visualização de árvore de diretórios com filtros |
| `auditoria.zsh` | Auditoria de repositórios por violações de anonimato |
| `busca.zsh` | Busca inteligente em arquivos e diretórios |
| `conjurar.zsh` | Menu FZF global de ferramentas do Andromeda |
| `controle-de-bordo.zsh` | Gestão de projetos, tarefas e notas |
| `diagnostico.zsh` | Diagnóstico completo de ambiente e dependências |
| `encoding.zsh` | Detecção e conversão de encoding (UTF-8, BOM, CRLF) |
| `extrair.zsh` | Extração inteligente de arquivos compactados |
| `fontes.zsh` | Instalação e verificação de fontes de compatibilidade |
| `git-add.zsh` | Git add interativo com preview |
| `git-contexto.zsh` | Identidade git automática por diretório |
| `git-recovery.zsh` | Recuperação de commits e branches perdidos |
| `hooks.zsh` | Aplicação de hooks git em repositórios |
| `limpeza.zsh` | Limpeza interativa de ambiente e temporários |
| `mec.zsh` | Menu FZF completo para projetos dbt/BigQuery (29 operações) |
| `navegacao.zsh` | Navegação inteligente entre diretórios de projetos |
| `projeto.zsh` | Criação e gestão de projetos |
| `pulso.zsh` | Monitor de sistema em tempo real (CPU, RAM, GPU) |
| `remoto.zsh` | Conexão e sync com máquina remota via SSH |
| `restaurar.zsh` | Backup e restauração de sistema via manifesto JSON |
| `sistema.zsh` | Captura de manifesto e diagnóstico do sistema |
| `spicetify.zsh` | Integração com Spicetify (customização do Spotify) |
| `sync-integrado.zsh` | Sincronização integrada de múltiplos repositórios |
| `sync.zsh` | Sincronização de repositórios com backup |
| `vault_automation.zsh` | Automação de export/import do vault GPG |

---

### Scripts auxiliares

#### Bash (10)

| Script | Uso |
|--------|-----|
| `instalar-extras.sh` | Instala fastfetch + earlyoom + Gradia (chamado pelo install.sh) |
| `clonar-repos.sh` | Clona/atualiza todos os repos pessoais do GitHub |
| `configurar-atalhos-cosmic.sh` | Configura atalhos de teclado no COSMIC DE |
| `andromeda-secrets.sh` | Exporta/importa credentials para vault GPG criptografado |
| `ritual-da-aurora.sh` | Configura GPU Nvidia + serviços ao iniciar |
| `ritual-da-aurora-user.sh` | Parte de usuário do ritual (nvidia-settings, sem sudo) |
| `auditoria-repos.sh` | Auditoria em lote de repositórios por violações |
| `fix_all_remotes.sh` | Corrige remotes SSH de todos os repositórios |
| `spicetify-setup.sh` | Instalação e configuração do Spicetify |
| `validate-ai-tools.sh` | Validação de ferramentas de IA instaladas |

#### Python (8)

| Script | Uso |
|--------|-----|
| `analisador-dados.py` | Analisa CSV/Excel e gera relatório de qualidade |
| `compat.py` | Utilitários de compatibilidade cross-platform |
| `conjurar-helper.py` | Helper para o menu FZF do conjurar |
| `mec-dbt-results.py` | Parser de `run_results.json` do dbt |
| `mec-migrar-censo.py` | Migração de tabelas INEP no BigQuery |
| `processar-planilha.py` | Processamento de planilhas Excel/CSV |
| `reconstrutor-helper.py` | Helper para reconstrução de estruturas de projeto |
| `universal-sanitizer.py` | Detecta rastros pessoais em arquivos staged |

---

### Secrets e credenciais

O install.sh oferece restauração automática de credentials via vault GPG criptografado (`vault/secrets.gpg`). Para popular o vault:

```bash
# 1. Preencher manualmente
nano ~/.config/zsh/.zsh_secrets

# 2. Exportar para o vault (criptografado com senha)
andromeda_export

# 3. Commitar o vault (o conteúdo é ilegível sem a senha)
git add vault/secrets.gpg
git commit -m "chore: atualizar vault de secrets"
git push
```

Em qualquer reinstalação futura, o install.sh pede a senha GPG e restaura tudo automaticamente.

| Variável | Uso |
|----------|-----|
| `GIT_TOKEN_PESSOAL` | GitHub Personal Access Token (repos pessoais) |
| `GIT_TOKEN_MEC` | GitHub PAT (repos MEC) |
| `ANTHROPIC_API_KEY` | Claude API |
| `GEMINI_API_KEY` | Gemini API |
| `DEEPSEEK_API_KEY` | DeepSeek API |
| `HUGGING_FACE_HUB_TOKEN` | Hugging Face |

---

### Configuração pós-instalação

| Arquivo | Conteúdo |
|---------|----------|
| `~/.config/zsh/config.local.zsh` | Caminhos locais, identidades git, `BQ_KEYFILE_PATH` |
| `~/.config/zsh/.zsh_secrets` | Tokens e API keys |
| `~/.config/zsh/profiles.yml` | Configuração dbt BigQuery |

---

### Comandos disponíveis

#### Navegação e arquivos

| Comando | Descrição |
|---------|-----------|
| `dev` | Ir para `~/Desenvolvimento` |
| `cfg` | Ir para `~/.config/zsh` |
| `mec` | Entrar no projeto pipelines-main |
| `encontre <padrão>` | Buscar arquivo por nome |
| `procure_por_texto <texto> <pasta>` | Buscar texto dentro de arquivos |

#### Git

| Comando | Descrição |
|---------|-----------|
| `gs` | Status resumido |
| `gl` | Log visual com grafo |
| `gc <msg>` | Commit com mensagem |
| `gac <msg>` | Add tudo + commit |
| `gp` | Push |
| `gup` | Pull com rebase |
| `gss` / `gsp` | Stash push / pop |

#### Sistema

| Comando | Descrição |
|---------|-----------|
| `atualizar_tudo` | Atualizar apt + flatpak + limpeza |
| `capturar` | Manifesto JSON do sistema |
| `restaurar` | Restaurar de manifesto |
| `diagnostico_pop` | Diagnóstico completo |
| `pulso` | Monitor em tempo real |
| `limpar` | Limpeza interativa |

#### Andromeda

| Comando | Descrição |
|---------|-----------|
| `andromeda_export` | Criptografar credentials no vault |
| `andromeda_import` | Restaurar credentials do vault |
| `andromeda_sync_status` | Estado do sync bidirecional |
| `andromeda_sync_force` | Forçar direção do sync |

---

### Estrutura

```
Andromeda-OS/
├── install.sh                      # Instalador com TUI whiptail (20 etapas)
├── uninstall.sh                    # Desinstalador interativo (seletivo)
├── requirements.txt                # Dependências Python
├── .zshrc                          # Entry point do zsh
├── env.zsh                         # Ambiente + Oh My Zsh + SSH agent
├── aliases.zsh                     # Aliases gerais
├── functions.zsh                   # Loader de módulos
├── AI.md                           # Protocolo para agentes de IA
├── mec-ai-guide.md                 # Contexto do projeto MEC para sessões de IA
├── config.local.zsh.template       # Template: vars por máquina
├── .zsh_secrets.template           # Template: tokens e API keys
├── profiles.yml.template           # Template: dbt BigQuery
├── vault/
│   └── secrets.gpg                 # Credentials criptografadas (AES256)
├── hooks/
│   ├── _lib.sh                     # Biblioteca compartilhada dos hooks
│   ├── pre-commit                  # Valida identidade + bloqueia secrets
│   ├── commit-msg                  # Valida formato da mensagem
│   ├── commit-template             # Template para mensagens de commit
│   └── pre-push                    # Valida remote SSH alias
├── cca/                            # Claude Code Aliases + quota guard
│   ├── aliases_cca.zsh
│   ├── cca_guard.sh
│   └── cca_quota_manager.sh
├── kca/                            # Kimi CLI Ultra aliases + docs
│   ├── aliases_kca.zsh
│   ├── AGENTS.md
│   └── KIMI_ULTRA.md
├── functions/                      # 27 módulos zsh
│   ├── _helpers.zsh
│   ├── andromeda-sync.zsh
│   ├── mec.zsh
│   ├── git-contexto.zsh
│   └── ...
└── scripts/                        # 10 bash + 8 Python
    ├── instalar-extras.sh
    ├── clonar-repos.sh
    ├── configurar-atalhos-cosmic.sh
    ├── andromeda-secrets.sh
    ├── ritual-da-aurora.sh
    └── *.py
```

---

### Licença

GPLv3 — Veja [LICENSE](LICENSE) para detalhes.
