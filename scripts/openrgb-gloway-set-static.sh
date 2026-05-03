#!/usr/bin/env bash
# Aplica Static + roxo (#8B00FF) nas Gloway DRAM RGB (controller ENE).
# Roda no boot (ExecStart) e no shutdown (ExecStop) do openrgb-gloway.service,
# e também via autostart user no login do Cosmic.
#
# Por que ExecStop é a parte importante:
# O controller ENE da Gloway memoriza o último estado SMBus escrito na NVRAM
# da própria pente. Aplicando Static logo antes do poweroff, o próximo boot
# (Linux OU Windows) acorda com Static memorizado — sem piscar.
#
# Auto-recovery do AppImage:
# `apt upgrade` pode bumpar kernel/glibc/libfuse e quebrar o runtime do
# AppImage (visto em 2026-05-03 com 1.0rc2 → SIGSEGV em mmap inicial). O
# script faz health check `--version` em 3 tentativas; se quebrado, tenta:
#   (1) restaurar do source (~/.config/zsh/scripts/openrgb.AppImage)
#   (2) re-baixar AppImage 0.9 stable da URL canônica + verificação SHA-256
# Só desiste com ALERTA loud se ambos falham (caso raro de internet down +
# source também corrompido).
#
# Fonte-de-verdade: ~/.config/zsh/scripts/openrgb-gloway-set-static.sh
# Destino: /usr/local/bin/openrgb-gloway-set-static.sh
set -u

USER_HOME=/home/vitoriamaria
OPENRGB="$USER_HOME/.local/bin/openrgb"
APPIMG_SRC="$USER_HOME/.config/zsh/scripts/openrgb.AppImage"
APPIMG_URL="https://codeberg.org/OpenRGB/OpenRGB/releases/download/release_0.9/OpenRGB_0.9_x86_64_b5f46e3.AppImage"
APPIMG_SHA256="b553010012d3a34dc0b570e1138d7466f00f088158ccf9f549a52d88d61b1ec0"
COLOR="${RGB_COLOR:-8B00FF}"

ts() { date -Iseconds; }

healthcheck() {
  for try in 1 2 3; do
    timeout 10 "$OPENRGB" --version >/dev/null 2>&1 && return 0
  done
  return 1
}

verify_sha256() {
  local file="$1" expected="$2"
  local actual
  actual=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
  [ "$actual" = "$expected" ]
}

# Determinar quem é dono do destino (pra cp restore — pode ser user ou root call)
target_owner=""
if [ -f "$OPENRGB" ]; then
  target_owner=$(stat -c '%U:%G' "$OPENRGB" 2>/dev/null || echo "")
fi

ensure_owner() {
  # Se rodando como root, garantir que arquivos no $USER_HOME ficam do user.
  local file="$1"
  if [ "$(id -u)" = "0" ]; then
    chown "vitoriamaria:vitoriamaria" "$file" 2>/dev/null || true
  fi
}

# === Etapa 1: garantir que o binário existe ===
if [ ! -x "$OPENRGB" ]; then
  if [ -f "$APPIMG_SRC" ]; then
    echo "[$(ts)] openrgb ausente — restaurando do source"
    install -D -m 755 "$APPIMG_SRC" "$OPENRGB"
    ensure_owner "$OPENRGB"
  else
    echo "[$(ts)] ERRO: openrgb ausente e source também — sai limpo."
    exit 0
  fi
fi

# === Etapa 2: health check com auto-recovery ===
if ! healthcheck; then
  echo "[$(ts)] ALERTA: openrgb segfault no health check — tentando recovery"

  # Tentativa A: restore do source-of-truth (caso destino tenha sido corrompido)
  if [ -f "$APPIMG_SRC" ] && verify_sha256 "$APPIMG_SRC" "$APPIMG_SHA256"; then
    echo "[$(ts)] recovery A: restaurando do source (sha256 ok)"
    install -D -m 755 "$APPIMG_SRC" "$OPENRGB"
    ensure_owner "$OPENRGB"
  fi

  if ! healthcheck; then
    # Tentativa B: re-baixar fresh da URL canônica (corrige source corrompido)
    echo "[$(ts)] recovery B: baixando AppImage 0.9 fresh de $APPIMG_URL"
    tmp=$(mktemp -p /tmp openrgb.XXXXXX.AppImage)
    if curl -fsSL --max-time 90 -o "$tmp" "$APPIMG_URL" \
       && verify_sha256 "$tmp" "$APPIMG_SHA256"; then
      echo "[$(ts)] recovery B: download ok + sha256 ok — aplicando"
      install -D -m 755 "$tmp" "$APPIMG_SRC"
      ensure_owner "$APPIMG_SRC"
      install -D -m 755 "$tmp" "$OPENRGB"
      ensure_owner "$OPENRGB"
      rm -f "$tmp"
    else
      echo "[$(ts)] recovery B: falhou (sem internet ou checksum mismatch)"
      rm -f "$tmp"
    fi
  fi

  if ! healthcheck; then
    echo "[$(ts)] ALERTA CRÍTICO: openrgb irrecuperável — sai sem aplicar RGB."
    echo "[$(ts)] verificar manualmente: $OPENRGB --version"
    exit 1
  fi
  echo "[$(ts)] recovery bem-sucedido"
fi

# === Etapa 3: SMBus disponível? ===
if command -v i2cdetect >/dev/null 2>&1; then
  if ! i2cdetect -l 2>/dev/null | grep -qi "SMBus"; then
    echo "[$(ts)] SMBus não disponível (i2c_piix4 não carregou? acpi_enforce_resources=lax pegou?) — sai limpo."
    exit 0
  fi
fi

# === Etapa 4: aplicar Static nas 2 pentes ===
# Itera por índice. OpenRGB 0.9 detecta as Gloway em devices 0 e 1
# (controller ENE em SMBus 0x72/0x73). Se a ordem mudar um dia, fallback é
# rodar o profile salvo via OpenRGB GUI.
for idx in 0 1; do
  timeout 15 "$OPENRGB" --noautoconnect --device "$idx" --mode Static --color "$COLOR" 2>&1 \
    | grep -v "^$" | grep -vE "Profile.*isn't valid|Running standalone" || true
done

exit 0
