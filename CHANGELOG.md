# Changelog

## [Não lançado]

### Adicionado
- **Ritual da Aurora v3 — overclock + RGB self-healed (2026-05-02)**
  - `scripts/openrgb-gloway.service`: aplica Static roxo (#8B00FF) nas Gloway DRAM RGB no boot **e** no shutdown (via `Before=shutdown.target` + `Conflicts=`). Resolve persistência da NVRAM do controller ENE — Windows acorda sem piscar
  - `scripts/openrgb-gloway-set-static.sh`: helper que aplica via `OpenRGB --noautoconnect --device N --mode Static --color`. Sai limpo se SMBus indisponível
  - `scripts/60-openrgb.rules`: udev `MODE=0666` em i2c/hidraw/nvidia
  - `scripts/openrgb-modules.conf`: `i2c-dev` + `i2c-piix4` em modules-load.d
  - `scripts/openrgb-gloway.desktop`: autostart user (camada de fallback)
  - `scripts/gloway-roxo.orp`: profile salvo
  - `scripts/openrgb.AppImage` (33MB): binário OpenRGB 1.0rc2 como fonte-de-verdade pra restauração
  - `scripts/dual-boot-defender.sh`: re-aplica neutralização do Windows (`bootmgfw.efi.DISABLED` + delete entry NVRAM EFI) — modo `--silent` para chamada do self-heal
  - `scripts/99-ritual-aurora-apt-hook`: `DPkg::Post-Invoke` dispara self-heal após cada apt operation (fecha janela de vulnerabilidade entre upgrade e timer)
  - `scripts/BIOS-CHECKLIST.md`: documentação fonte-de-verdade pra reaplicar config BIOS (ReBAR, XMP 3800, Curve -15/-20, PBO Manual 110W) caso CMOS limpe

### Alterado
- `scripts/ritual-aurora-self-heal.sh` (v2 → v3):
  - Cobre RGB Gloway, OpenRGB binary, dual-boot-defender, apt hook
  - `ensure_kernel_option`: agora gerencia `acpi_enforce_resources=lax`, `usbcore.autosuspend=-1`, `nvidia-drm.modeset=1` (além dos já cobertos `pcie_aspm=off`, `mitigations=off`, `threadirqs`)
  - `install_user_if_diff`: nova função pra arquivos no `$HOME` (preserva ownership), com fast-path `stat -c %s` antes de `cmp -s` pra evitar I/O em arquivos grandes (33MB AppImage)
  - Cria diretório pai com ownership correto antes de `install -D` (evita `~/.config/OpenRGB/` virar root-owned)
  - Self-heal cuida do próprio binário em `/usr/local/sbin/`
  - Tracking de erros via `err()` + exit 1 se `errors > 0` (apt hook detecta falhas)
  - Log auto-rotation: trunca pra últimas 1000 linhas quando > 5MB
  - Adiciona usuário ao grupo `i2c` (idempotente)
  - `modprobe` runtime de `i2c-dev`/`i2c-piix4` (modules-load.d só carrega no boot)
- `scripts/ritual-aurora-self-heal.timer`: `OnUnitActiveSec` 24h → **1h** + `RandomizedDelaySec=30s`

### Adicionado (anteriormente — não relacionado a RGB)
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
