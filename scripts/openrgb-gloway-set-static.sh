#!/usr/bin/env bash
# Aplica Static + roxo (#8B00FF) nas Gloway DRAM RGB (controller ENE).
# Roda no boot (ExecStart) e no shutdown (ExecStop) do openrgb-gloway.service.
#
# Por que ExecStop é a parte importante:
# O controller ENE da Gloway memoriza o último estado SMBus escrito na NVRAM
# da própria pente. Aplicando Static logo antes do poweroff, o próximo boot
# (Linux OU Windows) acorda com Static memorizado — sem piscar.
#
# Fonte-de-verdade: ~/.config/zsh/scripts/openrgb-gloway-set-static.sh
# Destino: /usr/local/bin/openrgb-gloway-set-static.sh
set -u

OPENRGB=/home/vitoriamaria/.local/bin/openrgb
COLOR="${RGB_COLOR:-8B00FF}"

[ -x "$OPENRGB" ] || { echo "openrgb não encontrado em $OPENRGB — sai limpo."; exit 0; }

# Verificar SMBus disponível. Se i2c-tools não estiver instalado, pular check
# (OpenRGB falhará graciosamente se realmente não houver SMBus).
if command -v i2cdetect >/dev/null 2>&1; then
  if ! i2cdetect -l 2>/dev/null | grep -qi "SMBus"; then
    echo "SMBus não disponível (i2c_piix4 não carregou? acpi_enforce_resources=lax pegou?) — sai limpo."
    exit 0
  fi
fi

# Aplica nos devices DRAM (ENE) detectados. Itera por índice — se um dia a
# ordem mudar, o profile salvo em ~/.config/OpenRGB/gloway-roxo.orp serve de
# fallback via autostart user.
for idx in 0 1; do
  "$OPENRGB" --noautoconnect --device "$idx" --mode Static --color "$COLOR" 2>&1 \
    | grep -v "^$" || true
done

exit 0
