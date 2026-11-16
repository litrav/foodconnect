# FoodConnect

Sistema que conecta **excedentes de alimentos** de restaurantes, padarias e mercados a **instituições** que atendem pessoas em situação de vulnerabilidade. Ele controla quantidade e validade, registra as doações, mede o impacto e prevê quanto cada estabelecimento deve ofertar na semana.

Projeto da A3 de Banco de Dados (Universidade Anhembi Morumbi), feito por Pedro Henrique Trofino Queiroz e João Vitor Dias Freire.

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `db/` | Scripts SQL do MySQL 8: estrutura, dados de teste, testes de integridade, usuário da aplicação e DER |
| `backend/` | API REST em Node.js + Express |
| `frontend/` | Site (HTML, CSS e JavaScript), servido pela própria API |
| `deploy/` | Scripts de publicação na Oracle Cloud e teste da API |

## Banco de dados (MySQL 8)

Rode os scripts nesta ordem:

```bash
mysql -u root -p < db/01_foodconnect_ddl.sql          # tabelas, views, procedures e evento
mysql -u root -p < db/02_dados_cadastros.sql          # cadastros e situação atual (teste)
mysql -u root -p < db/03_dados_historico_teste.sql    # 12 semanas de histórico SIMULADO + previsão
mysql -u root -p --force < db/04_testes_integridade.sql   # todos os comandos devem ser recusados
# edite a senha em db/05_usuario_aplicacao.sql e rode:
mysql -u root -p < db/05_usuario_aplicacao.sql
```

São 9 tabelas, 6 views, 2 procedures e 1 evento diário. A análise preditiva usa média móvel ponderada (4 semanas, pesos 4-3-2-1) calculada com funções de janela. A acurácia do método é medida no histórico (`vw_acuracia_previsao`).

## API e site (local)

```bash
cd backend
cp .env.example .env      # preencha DB_PASS e TOKEN_SECRET
npm install
npm start                 # http://localhost:3000
```

Todas as contas de demonstração usam a senha `FoodConnect@2026`, guardada no banco só como hash bcrypt.

| Método | Rota | Quem usa |
|---|---|---|
| POST | `/api/login` | todos |
| GET | `/api/excedentes`, `/api/indicadores`, `/api/previsoes`, `/api/saude` | público |
| POST | `/api/excedentes` · GET `/api/meus-excedentes` | estabelecimento |
| POST | `/api/doacoes` (transação com `SELECT ... FOR UPDATE`) | instituição |
| GET | `/api/minhas-doacoes` · PATCH `/api/doacoes/:id/retirada` | instituição |

Teste rápido dos fluxos: `bash deploy/teste_api.sh http://localhost:3000`.

## Publicação na Oracle Cloud (plano gratuito)

- **Banco:** MySQL HeatWave (Always Free), numa subnet privada, sem acesso pela internet.
- **API e site:** máquina virtual Ubuntu (Always Free), com nginx na porta 80.

```bash
# na máquina virtual
git clone <URL deste repositório> foodconnect && cd foodconnect
DB_HOST=<IP privado do HeatWave> bash deploy/carregar_banco.sh
DB_HOST=<IP privado do HeatWave> bash deploy/instalar_vm.sh
```
