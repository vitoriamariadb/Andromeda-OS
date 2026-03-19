# Changelog

## [Não lançado]

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
- Configuração zsh modular com 23 módulos de funções
- Menu FZF interativo para projetos dbt/BigQuery
- Controle automático de identidade git por contexto
- Integração com Oh My Zsh
- 9 scripts Python utilitários
- Script de instalação único para Linux
- Templates de configuração local
