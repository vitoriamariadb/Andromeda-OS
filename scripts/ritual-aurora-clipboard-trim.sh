#!/usr/bin/env bash
# /usr/local/bin/ritual-aurora-clipboard-trim.sh
# Gerenciado pelo Ritual da Aurora — fonte de verdade em ~/.config/zsh/scripts/ritual-aurora-clipboard-trim.sh
#
# Trima o sqlite do cosmic-ext-applet-clipboard-manager (flatpak) mantendo
# apenas as últimas KEEP_ROWS entradas por tabela, e rodando VACUUM.
# Sem isso, o histórico cresce sem limite (vimos 1GB+ em 3 semanas).
#
# Roda como user (via systemd --user). Idempotente.

set -u
KEEP_ROWS=200
DB_DIR="$HOME/.var/app/io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager/cache/cosmic-ext-applet-clipboard-manager"
LOG="$HOME/.local/state/ritual-aurora-clipboard-trim.log"

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1

echo "================================================================"
echo "$(date -Iseconds) — clipboard-trim run"

DB=$(ls -1 "$DB_DIR"/*.sqlite 2>/dev/null | head -1 || true)
if [ -z "${DB:-}" ] || [ ! -f "$DB" ]; then
  echo "  pula: sqlite db não encontrado em $DB_DIR"
  exit 0
fi

if ! command -v sqlite3 >/dev/null; then
  echo "  ERRO: sqlite3 não instalado"
  exit 1
fi

SIZE_BEFORE=$(stat -c%s "$DB" 2>/dev/null || echo 0)
echo "  db: $DB ($(numfmt --to=iec "$SIZE_BEFORE" 2>/dev/null || echo "$SIZE_BEFORE bytes"))"

# Lista tabelas user-defined
TABLES=$(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_sqlx_%';" 2>/dev/null)
if [ -z "$TABLES" ]; then
  echo "  pula: nenhuma tabela user-defined encontrada"
  exit 0
fi

for t in $TABLES; do
  COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM \"$t\";" 2>/dev/null || echo 0)
  echo "  tabela $t: $COUNT linhas"
  if [ "$COUNT" -gt "$KEEP_ROWS" ]; then
    sqlite3 "$DB" "DELETE FROM \"$t\" WHERE rowid NOT IN (SELECT rowid FROM \"$t\" ORDER BY rowid DESC LIMIT $KEEP_ROWS);" 2>&1 || echo "  WARN: delete falhou em $t"
    NEW=$(sqlite3 "$DB" "SELECT COUNT(*) FROM \"$t\";" 2>/dev/null || echo "?")
    echo "    -> $NEW linhas após trim"
  fi
done

echo "  VACUUM"
sqlite3 "$DB" "VACUUM;" 2>&1 || echo "  WARN: VACUUM falhou (db pode estar locked pelo applet — tentar de novo no próximo run)"

# WAL checkpoint TRUNCATE — força o write-ahead-log a ser merged no main db e truncated.
# Sem isso, o -wal pode ficar GBs mesmo com main db pequeno (applet mantém handle aberto).
echo "  WAL checkpoint TRUNCATE"
sqlite3 "$DB" "PRAGMA wal_checkpoint(TRUNCATE);" 2>&1 || echo "  WARN: wal_checkpoint falhou"

SIZE_AFTER=$(stat -c%s "$DB" 2>/dev/null || echo 0)
WAL_AFTER=$(stat -c%s "$DB-wal" 2>/dev/null || echo 0)
TOTAL_AFTER=$((SIZE_AFTER + WAL_AFTER))
echo "  db agora: $(numfmt --to=iec "$SIZE_AFTER" 2>/dev/null || echo "$SIZE_AFTER B") + wal $(numfmt --to=iec "$WAL_AFTER" 2>/dev/null || echo "$WAL_AFTER B")"
echo "  OK"
