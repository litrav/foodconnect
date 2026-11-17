#!/usr/bin/env bash
# =====================================================================
# FoodConnect - atualiza o site que já está publicado na máquina virtual
# Uso (na VM, dentro da pasta foodconnect):  bash deploy/atualizar.sh
# O que faz: baixa o código novo do GitHub, cria a view de indicadores
# mensais no banco e reinicia a API.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

echo ">> Baixando o código novo..."
git pull

DB_HOST=$(grep '^DB_HOST=' backend/.env | cut -d= -f2)
DB_ADMIN=${DB_ADMIN:-admin}
read -rsp "Senha do usuário $DB_ADMIN do HeatWave: " ADMIN_PASS; echo
export MYSQL_PWD="$ADMIN_PASS"

echo ">> Criando a view de indicadores mensais..."
mysql -h "$DB_HOST" -u "$DB_ADMIN" --default-character-set=utf8mb4 < db/06_indicadores_mensais.sql
mysql -h "$DB_HOST" -u "$DB_ADMIN" -t foodconnect_db -e "SELECT * FROM vw_indicadores_mensais"
unset MYSQL_PWD

echo ">> Reiniciando a API..."
sudo systemctl restart foodconnect
sleep 2
curl -s http://localhost/api/indicadores/mensal | head -c 200; echo
echo "Pronto! Atualize o site no navegador (Ctrl+F5)."
