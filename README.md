<div align="center">

[![opensource](https://badges.frapsoft.com/os/v1/open-source.png?v=103)](#)
[![Licença](https://img.shields.io/badge/licença-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Zsh](https://img.shields.io/badge/shell-zsh-green.svg)](https://www.zsh.org/)
[![Oh My Zsh](https://img.shields.io/badge/Oh%20My%20Zsh-compatible-blue.svg)](https://ohmyz.sh/)

<h1>Andromeda OS</h1>

</div>

---

Configuração zsh modular e portável para Pop!\_OS 24.04 + COSMIC DE. 23 módulos de funções, 9 scripts Python, menu FZF interativo para projetos dbt/BigQuery, controle automático de identidade git por diretório e integração com Oh My Zsh. Formatou o PC — clone o repo e rode `./install.sh`. O resto é automático.

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

### Módulos zsh

| Módulo | Descrição |
|--------|-----------|
| `functions/mec.zsh` | Menu FZF completo para projetos dbt/BigQuery (29 operações) |
| `functions/git-contexto.zsh` | Identidade git automática por diretório |
| `functions/conjurar.zsh` | Menu FZF global de ferramentas |
| `functions/diagnostico.zsh` | Diagnóstico de ambiente e dependências |
| `functions/andromeda-sync.zsh` | Sincronização bidirecional do Andromeda-OS |
| `functions/sync.zsh` | Sincronização de repositórios com backup |
| `functions/controle-de-bordo.zsh` | Gestão de projetos e tarefas |
| `functions/projeto.zsh` | Criação e gestão de projetos |
| `functions/pulso.zsh` | Monitor de sistema em tempo real |
| `functions/limpeza.zsh` | Limpeza de ambiente e temporários |
| `functions/encoding.zsh` | Detecção e conversão de encoding (UTF-8, CRLF) |
| `functions/fontes.zsh` | Instalação e verificação de fontes de compatibilidade |
| `functions/restaurar.zsh` | Backup e restauração de sistema via manifesto |
| `functions/sistema.zsh` | Captura de manifesto e diagnóstico do sistema |
| `functions/remoto.zsh` | Conexão e sync com máquina remota |
| `functions/_helpers.zsh` | Paleta Dracula + utilitários base |

---

### Scripts auxiliares

| Script | Uso |
|--------|-----|
| `scripts/instalar-extras.sh` | Instala earlyoom + Gradia (chamado pelo install.sh) |
| `scripts/clonar-repos.sh` | Clona/atualiza todos os repos pessoais do GitHub |
| `scripts/configurar-atalhos-cosmic.sh` | Configura atalhos de teclado no COSMIC DE |
| `scripts/andromeda-secrets.sh` | Exporta/importa credentials para vault GPG criptografado |
| `scripts/ritual-da-aurora.sh` | Configura GPU Nvidia + serviços ao iniciar |
| `scripts/mec-dbt-results.py` | Parser de `run_results.json` do dbt |
| `scripts/mec-migrar-censo.py` | Migração de tabelas INEP no BigQuery |
| `scripts/universal-sanitizer.py` | Detecta rastros pessoais em arquivos staged |
| `scripts/analisador-dados.py` | Analisa CSV/Excel e gera relatório de qualidade |

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

### Estrutura

```
Andromeda-OS/
├── install.sh                      # Instalador com TUI whiptail (20 etapas)
├── requirements.txt                # Dependências Python
├── .zshrc                          # Entry point do zsh
├── env.zsh                         # Ambiente + Oh My Zsh + SSH agent
├── aliases.zsh                     # Aliases gerais
├── functions.zsh                   # Loader de módulos
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
│   └── pre-push                    # Valida remote SSH alias
├── functions/                      # 16+ módulos zsh
│   ├── _helpers.zsh
│   ├── mec.zsh
│   ├── git-contexto.zsh
│   └── ...
└── scripts/                        # Scripts bash + Python
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
