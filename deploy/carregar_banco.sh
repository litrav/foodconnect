#!/usr/bin/env bash
# =====================================================================
# FoodConnect - carrega o banco no MySQL HeatWave (Oracle Cloud)
# Rode na máquina virtual, dentro da pasta do projeto:
#   DB_HOST=10.0.1.xxx ./deploy/carregar_banco.sh
# Pede a senha do usuário "admin" do HeatWave e a senha nova do
# usuário da aplicação (foodconnect_app). Nenhuma senha fica salva aqui.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

DB_HOST=${DB_HOST:?Informe o IP privado do HeatWave: DB_HOST=10.0.1.xxx ./deploy/carregar_banco.sh}
DB_ADMIN=${DB_ADMIN:-admin}

if ! command -v mysql >/dev/null; then
  echo ">> Instalando o cliente MySQL..."
  sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-client
fi

read -rsp "Senha do usuário $DB_ADMIN do HeatWave: " ADMIN_PASS; echo
read -rsp "Crie uma senha para o usuário da aplicação (foodconnect_app): " APP_PASS; echo
export MYSQL_PWD="$ADMIN_PASS"
M="mysql -h $DB_HOST -u $DB_ADMIN --default-character-set=utf8mb4"

echo ">> Criando estrutura (tabelas, views, procedures e evento)..."
$M < db/01_foodconnect_ddl.sql
echo ">> Inserindo cadastros e situação atual..."
$M < db/02_dados_cadastros.sql
echo ">> Inserindo histórico simulado e gerando a previsão..."
$M < db/03_dados_historico_teste.sql
echo ">> Criando usuário da aplicação com privilégio mínimo..."
sed -e "s/TROQUE_ESTA_SENHA/${APP_PASS//\//\\/}/" -e "s/'localhost'/'%'/g" db/05_usuario_aplicacao.sql | $M
echo ">> Conferindo:"
$M -t -e "SELECT COUNT(*) AS excedentes FROM foodconnect_db.excedente; SELECT * FROM foodconnect_db.vw_indicadores; SHOW VARIABLES LIKE 'event_scheduler';"
unset MYSQL_PWD
echo "Banco pronto. Guarde a senha do foodconnect_app: ela vai no .env da API."
