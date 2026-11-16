#!/usr/bin/env bash
# =====================================================================
# FoodConnect - instala a API e o site na máquina virtual (Ubuntu) da Oracle Cloud
# Uso (na VM):
#   git clone <URL do repositório> foodconnect && cd foodconnect
#   DB_HOST=10.0.1.xxx ./deploy/instalar_vm.sh
# O que faz: instala Node.js 22, nginx e cliente MySQL; instala a API como
# serviço (sobe sozinha se a VM reiniciar); publica o site na porta 80.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
APP_DIR=$(pwd)
DB_HOST=${DB_HOST:?Informe o IP privado do HeatWave: DB_HOST=10.0.1.xxx ./deploy/instalar_vm.sh}

echo ">> Instalando pacotes..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx mysql-client curl ca-certificates iptables-persistent
if ! command -v node >/dev/null || [ "$(node -v | cut -d. -f1 | tr -d v)" -lt 20 ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

echo ">> Instalando dependências da API..."
cd "$APP_DIR/backend" && npm install --omit=dev

if [ ! -f .env ]; then
  read -rsp "Senha do usuário foodconnect_app (a mesma do carregar_banco.sh): " APP_PASS; echo
  cat > .env <<EOF
DB_HOST=$DB_HOST
DB_PORT=3306
DB_USER=foodconnect_app
DB_PASS=$APP_PASS
DB_NAME=foodconnect_db
TOKEN_SECRET=$(openssl rand -hex 32)
PORT=3000
EOF
  chmod 600 .env
fi

echo ">> Criando o serviço foodconnect (systemd)..."
sudo tee /etc/systemd/system/foodconnect.service >/dev/null <<EOF
[Unit]
Description=FoodConnect API
After=network-online.target

[Service]
WorkingDirectory=$APP_DIR/backend
ExecStart=$(command -v node) --env-file=.env server.js
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now foodconnect
sudo systemctl restart foodconnect

echo ">> Configurando nginx (porta 80 -> API na porta 3000)..."
sudo tee /etc/nginx/sites-available/foodconnect >/dev/null <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF
sudo ln -sf /etc/nginx/sites-available/foodconnect /etc/nginx/sites-enabled/foodconnect
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx

echo ">> Liberando a porta 80 no firewall interno do Ubuntu..."
# a regra precisa ficar ANTES do REJECT que as imagens Ubuntu da Oracle trazem
while sudo iptables -C INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT 2>/dev/null; do
  sudo iptables -D INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
done
POS=$(sudo iptables -L INPUT --line-numbers -n | awk '$2=="REJECT"{print $1; exit}')
sudo iptables -I INPUT "${POS:-1}" -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo netfilter-persistent save

sleep 2
echo ">> Teste:"
curl -s http://localhost/api/saude; echo
IP=$(curl -s https://ifconfig.me || true)
echo "Pronto! Abra no navegador: http://$IP"
