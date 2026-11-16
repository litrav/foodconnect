"""Gera 02_dados_cadastros.sql e 03_dados_historico_teste.sql.
Todas as datas são relativas a CURDATE(), para a demonstração nunca ficar desatualizada.
O histórico é SIMULADO (dados de teste), com tendências diferentes por estabelecimento,
para alimentar a análise preditiva."""
import pathlib, random
import bcrypt

ROOT = pathlib.Path(__file__).parent
random.seed(2026)
SENHA_DEMO = b"FoodConnect@2026"

def h(): return bcrypt.hashpw(SENHA_DEMO, bcrypt.gensalt(10)).decode()

usuarios = [
 ("Marcos Pereira", "contato@paodamooca.com.br", "1126051111", "estabelecimento"),
 ("Juliana Ramos", "contato@saborcaseiro.com.br", "1126052222", "estabelecimento"),
 ("Ricardo Tanaka", "contato@bompreco.com.br", "1126053333", "estabelecimento"),
 ("Fernanda Lima", "contato@pratocheio.org.br", "1126054444", "instituicao"),
 ("Paulo Henrique Souza", "contato@abrigoesperanca.org.br", "1126055555", "instituicao"),
 ("Cláudia Martins", "contato@bancoleste.org.br", "1126056666", "instituicao"),
 ("Equipe FoodConnect", "admin@foodconnect.com.br", None, "admin"),
]

cad = ["-- =====================================================================",
       "-- FoodConnect - Checkpoint 3",
       "-- 02 - Cadastros e situação atual (dados de TESTE, fictícios)",
       "-- Senha de demonstração de todos os usuários: FoodConnect@2026 (guardada só como hash bcrypt)",
       "-- =====================================================================",
       "USE foodconnect_db;", "SET NAMES utf8mb4;", "",
       "INSERT INTO usuario (nome, email, senha_hash, telefone, perfil) VALUES"]
cad.append(",\n".join(f"('{n}', '{e}', '{h()}', {repr(t) if t else 'NULL'}, '{p}')" for n, e, t, p in usuarios) + ";")
cad += ["""
INSERT INTO endereco (logradouro, numero, complemento, bairro, cep, latitude, longitude) VALUES
('Rua da Mooca', '1500', NULL, 'Mooca', '03103002', -23.556700, -46.599800),
('Rua Bresser', '320', NULL, 'Brás', '03053000', -23.541900, -46.610200),
('Av. Paes de Barros', '1100', 'Loja 2', 'Mooca', '03114000', -23.565400, -46.590300),
('Rua Taquari', '800', NULL, 'Mooca', '03166000', -23.559800, -46.586100),
('Av. Radial Leste', '2500', NULL, 'Belém', '03071000', -23.543100, -46.594700),
('Rua Siqueira Bueno', '450', 'Galpão', 'Belenzinho', '03172010', -23.548900, -46.583200);

INSERT INTO estabelecimento (id_usuario, id_endereco, razao_social, nome_fantasia, cnpj, tipo) VALUES
(1, 1, 'Pão da Mooca Panificadora Ltda', 'Padaria Pão da Mooca', '11222333000101', 'padaria'),
(2, 2, 'Sabor Caseiro Alimentação Ltda', 'Restaurante Sabor Caseiro', '22333444000102', 'restaurante'),
(3, 3, 'Bom Preço Comércio de Alimentos Ltda', 'Mercado Bom Preço', '33444555000103', 'supermercado');

INSERT INTO instituicao (id_usuario, id_endereco, nome, cnpj, tipo, capacidade_kg_dia, pessoas_atendidas) VALUES
(4, 4, 'ONG Prato Cheio', '44555666000104', 'ong', 80.00, 150),
(5, 5, 'Casa Abrigo Esperança', '55666777000105', 'abrigo', 40.00, 60),
(6, 6, 'Banco de Alimentos Zona Leste', '66777888000106', 'banco_alimentos', 300.00, 900);

INSERT INTO categoria_alimento (nome, descricao, requer_refrigeracao) VALUES
('Panificados', 'Pães, bolos e salgados assados', FALSE),
('Refeições prontas', 'Pratos preparados no dia', TRUE),
('Hortifrúti', 'Frutas, legumes e verduras', FALSE),
('Laticínios', 'Leite, iogurtes e queijos', TRUE);

-- fator_kg: peso médio de 1 unidade (para un/l)
INSERT INTO alimento (id_categoria, nome, unidade_medida, fator_kg) VALUES
(1, 'Pão francês', 'kg', 1.000),
(1, 'Bolo simples', 'un', 0.600),
(2, 'Marmita arroz, feijão e frango', 'un', 0.450),
(3, 'Banana prata', 'kg', 1.000),
(3, 'Tomate', 'kg', 1.000),
(4, 'Iogurte natural', 'un', 0.170);

-- Situação da semana atual (ids 1 a 6)
INSERT INTO excedente (id_excedente, id_estabelecimento, id_alimento, quantidade, quantidade_disponivel, data_validade, data_cadastro, status, observacoes) VALUES
(1, 1, 1, 12.00, 0.00, CURDATE() - INTERVAL 1 DAY, NOW() - INTERVAL 30 HOUR, 'esgotado', 'Sobra do turno da tarde'),
(2, 1, 2, 8.00, 8.00, CURDATE() + INTERVAL 2 DAY, NOW() - INTERVAL 4 HOUR, 'disponivel', NULL),
(3, 2, 3, 20.00, 0.00, CURDATE(), NOW() - INTERVAL 6 HOUR, 'reservado', 'Retirar até 21h'),
(4, 3, 4, 25.00, 15.00, CURDATE() + INTERVAL 4 DAY, NOW() - INTERVAL 5 HOUR, 'disponivel', 'Maduras, boas para consumo'),
(5, 3, 5, 18.00, 18.00, CURDATE() + INTERVAL 3 DAY, NOW() - INTERVAL 3 HOUR, 'disponivel', NULL),
(6, 3, 6, 40.00, 40.00, CURDATE() + INTERVAL 1 DAY, NOW() - INTERVAL 2 HOUR, 'disponivel', 'Validade curta');

INSERT INTO doacao (id_excedente, id_instituicao, quantidade, data_solicitacao, data_retirada, status) VALUES
(1, 1, 12.00, NOW() - INTERVAL 26 HOUR, NOW() - INTERVAL 24 HOUR, 'retirada'),
(3, 2, 20.00, NOW() - INTERVAL 5 HOUR, NULL, 'aprovada'),
(4, 3, 10.00, NOW() - INTERVAL 3 HOUR, NULL, 'solicitada');
"""]
(ROOT / "02_dados_cadastros.sql").write_text("\n".join(cad), encoding="utf-8")

# ------------------------------------------------------------------ histórico simulado
# (estabelecimento, [(id_alimento, fator_kg, peso no mix)], kg/semana há 12 semanas, kg/semana na última)
PARES = [
 (1, [(1, 1.0, 0.7), (2, 0.6, 0.3)], 28.0, 40.0),   # padaria: oferta crescendo
 (2, [(3, 0.45, 1.0)],               24.0, 24.0),   # restaurante: estável
 (3, [(4, 1.0, 0.55), (5, 1.0, 0.45)], 48.0, 32.0), # mercado/hortifrúti: caindo
 (3, [(6, 0.17, 1.0)],                8.0, 10.0),   # mercado/laticínios: leve alta
]
SEM = 12
segunda = "(CURDATE() - INTERVAL WEEKDAY(CURDATE()) DAY)"
exc, doa = [], []
nid = 101
for est, mix, k0, k1 in PARES:
    for w in range(SEM, 0, -1):                       # w semanas atrás
        alvo = k0 + (k1 - k0) * (SEM - w) / (SEM - 1)
        alvo *= random.uniform(0.85, 1.15)            # ruído de ±15%
        for _ in range(3):                            # 3 ofertas na semana
            ida, fk, peso = random.choices(mix, weights=[m[2] for m in mix])[0]
            kg = alvo / 3 * random.uniform(0.8, 1.2)
            qtd = round(kg / fk) if fk != 1.0 else round(kg, 1)
            qtd = max(qtd, 1)
            dia, hora = random.randint(0, 6), random.randint(9, 20)
            dt = f"{segunda} - INTERVAL {7 * w - dia} DAY + INTERVAL {hora} HOUR"
            val = f"{segunda} - INTERVAL {7 * w - dia - random.randint(2, 5)} DAY"
            vencido = random.random() < 0.1
            if vencido:
                sobra = qtd if random.random() < 0.5 else round(qtd / 2, 1 if fk == 1.0 else 0)
                status = "vencido"
            else:
                sobra, status = 0, "esgotado"
            exc.append(f"({nid}, {est}, {ida}, {qtd}, {sobra}, {val}, {dt}, '{status}', 'Histórico simulado (teste)')")
            doado = qtd - sobra
            if doado > 0:
                inst = random.choice([1, 2, 3])
                doa.append(f"({nid}, {inst}, {doado}, {dt} + INTERVAL 2 HOUR, {dt} + INTERVAL 20 HOUR, 'retirada')")
            nid += 1

hist = ["-- =====================================================================",
        "-- FoodConnect - Checkpoint 3",
        "-- 03 - Histórico SIMULADO das últimas 12 semanas (dados de TESTE)",
        "-- Gerado por gera_dados.py com tendências diferentes por estabelecimento,",
        "-- só para alimentar e validar a análise preditiva. Datas relativas a CURDATE().",
        "-- =====================================================================",
        "USE foodconnect_db;", "SET NAMES utf8mb4;", "",
        "INSERT INTO excedente (id_excedente, id_estabelecimento, id_alimento, quantidade, quantidade_disponivel, data_validade, data_cadastro, status, observacoes) VALUES",
        ",\n".join(exc) + ";", "",
        "INSERT INTO doacao (id_excedente, id_instituicao, quantidade, data_solicitacao, data_retirada, status) VALUES",
        ",\n".join(doa) + ";", "",
        "-- grava a previsão desta semana na tabela previsao_excedente",
        "CALL sp_gerar_previsoes();"]
(ROOT / "03_dados_historico_teste.sql").write_text("\n".join(hist) + "\n", encoding="utf-8")
print(len(exc), "excedentes históricos,", len(doa), "doações")
