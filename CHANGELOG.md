# Changelog

## [Não lançado]

### Adicionado
- `uninstall.sh`: desinstalador interativo com TUI whiptail e paleta Dracula, selecao individual de componentes, backup automatico de configs sensiveis, suporte a `--dry-run` e `--force`
- `install.sh`: manifesto de instalacao em `~/.local/share/andromeda/install-manifest.json`
- `install.sh`: `python3-venv` adicionado as dependencias (necessario para `python3 -m venv`)

### Alterado
- `install.sh`: contagem de etapas agora e automatica (array STEPS no main)
- `install.sh`: etapa de atalhos COSMIC pula automaticamente se DE nao for COSMIC
- `install.sh`: etapa Ritual da Aurora pula automaticamente se GPU Nvidia nao detectada

### Corrigido
- `instalar-extras.sh`: uso de `local` fora de função causava falha na etapa [3/20] e impedia a instalação do fastfetch
- `.zshrc`: `eval "$(pyenv init -)"` executava incondicionalmente, causando "command not found: pyenv" ao abrir o terminal quando pyenv não está instalado

### Alterado
- `.zshrc`: inicialização do pyenv agora é condicional — só carrega se `~/.pyenv/bin` existir
- `README.md`: atualizado com contagem real de módulos (27), scripts (10 bash + 8 python), tabelas completas de todos os módulos e scripts, seção de comandos disponíveis e estrutura de diretórios precisa

## [1.1.0] - TUI e encoding

### Adicionado
- Navegação "Voltar" entre etapas do TUI (máquina de estados com `--cancel-button`)
- Detecção automática de variáveis de ambiente existentes em todas as etapas do TUI
- Label "Perfil Profissional" no lugar de "Identidade MEC" nos diálogos TUI
- Mensagem de sucesso ao final da instalação
- Módulo `encoding.zsh` — detecção e conversão de encoding (UTF-8, CRLF)
- Módulo `fontes.zsh` — instalação e verificação de fontes de compatibilidade
- Módulo `restaurar.zsh` — backup e restauração de sistema via manifesto
- Etapa de instalação de fontes base (ttf-mscorefonts, Liberation, Noto)
- Etapa de ferramentas de encoding (dos2unix)

### Corrigido
- Bug de corrupção do `config.local.zsh` na substituição `$HOME` → `${HOME}` via heredoc
- Título do TUI invisível no Cosmic DE (lightcyan → white)
- Skip inteligente do TUI quando configuração existente é detectada

## [1.0.0] - 2023-01-01

### Adicionado
- Configuração zsh modular com 27 módulos de funções
- Menu FZF interativo para projetos dbt/BigQuery
- Controle automático de identidade git por contexto
- Integração com Oh My Zsh
- 8 scripts Python utilitários
- 10 scripts bash auxiliares
- Script de instalação único para Linux (20 etapas com TUI)
- Templates de configuração local
- Vault GPG para credentials criptografadas
- Hooks git globais (pre-commit, commit-msg, pre-push)
- Ritual da Aurora (GPU Nvidia + systemd)
- Atalhos COSMIC DE
