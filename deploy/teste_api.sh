#!/usr/bin/env bash
# Testa os principais fluxos da API. Uso: ./teste_api.sh [URL]   (padrão: http://localhost:3000)
BASE=${1:-http://localhost:3000}
J='Content-Type: application/json'
tok() { curl -s -X POST "$BASE/api/login" -H "$J" -d "{\"email\":\"$1\",\"senha\":\"FoodConnect@2026\"}" | sed -E 's/.*"token":"([^"]+)".*/\1/'; }
st()  { echo "  -> HTTP $(tail -n1 <<<"$1")  $(head -n -1 <<<"$1")"; }

echo "1) Saúde da API e do banco";            st "$(curl -s -w '\n%{http_code}' "$BASE/api/saude")"
echo "2) Login com senha errada";              st "$(curl -s -w '\n%{http_code}' -X POST "$BASE/api/login" -H "$J" -d '{"email":"contato@pratocheio.org.br","senha":"errada"}')"
TE=$(tok contato@paodamooca.com.br); TI=$(tok contato@pratocheio.org.br)
echo "3) Padaria cadastra excedente (5 kg de pão francês)"
R=$(curl -s -w '\n%{http_code}' -X POST "$BASE/api/excedentes" -H "$J" -H "Authorization: Bearer $TE" \
     -d "{\"id_alimento\":1,\"quantidade\":5,\"data_validade\":\"$(date -d tomorrow +%F)\",\"observacoes\":\"Teste da API\"}"); st "$R"
ID=$(head -n -1 <<<"$R" | sed -E 's/.*"id_excedente":([0-9]+).*/\1/')
echo "4) Sem login, tentar solicitar doação";  st "$(curl -s -w '\n%{http_code}' -X POST "$BASE/api/doacoes" -H "$J" -d "{\"id_excedente\":$ID,\"quantidade\":3}")"
echo "5) Padaria tentando solicitar (perfil errado)"; st "$(curl -s -w '\n%{http_code}' -X POST "$BASE/api/doacoes" -H "$J" -H "Authorization: Bearer $TE" -d "{\"id_excedente\":$ID,\"quantidade\":3}")"
echo "6) ONG solicita 3 kg (há saldo)";        R=$(curl -s -w '\n%{http_code}' -X POST "$BASE/api/doacoes" -H "$J" -H "Authorization: Bearer $TI" -d "{\"id_excedente\":$ID,\"quantidade\":3}"); st "$R"
DID=$(head -n -1 <<<"$R" | sed -E 's/.*"id_doacao":([0-9]+).*/\1/')
echo "7) ONG pede mais 3 kg (só restam 2)";     st "$(curl -s -w '\n%{http_code}' -X POST "$BASE/api/doacoes" -H "$J" -H "Authorization: Bearer $TI" -d "{\"id_excedente\":$ID,\"quantidade\":3}")"
echo "8) ONG confirma a retirada";             st "$(curl -s -w '\n%{http_code}' -X PATCH "$BASE/api/doacoes/$DID/retirada" -H "Authorization: Bearer $TI")"
echo "9) Previsão desta semana (resumo)"
curl -s "$BASE/api/previsoes" | python3 -c "import json,sys; [print(f\"  {p['estabelecimento']:27} {p['categoria']:18} {p['kg_previsto']:>7} kg  {p['tendencia']}\") for p in json.load(sys.stdin)['previsao']]"
