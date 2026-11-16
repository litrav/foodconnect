-- =====================================================================
-- FoodConnect - Checkpoint 3
-- 04 - Testes de integridade: todos estes comandos DEVEM ser recusados
-- Rode com: mysql --force -u root < 04_testes_integridade.sql
-- =====================================================================
USE foodconnect_db;
SET NAMES utf8mb4;

-- T1: disponível maior que a quantidade total (CHECK)
INSERT INTO excedente (id_estabelecimento, id_alimento, quantidade, quantidade_disponivel, data_validade)
VALUES (1, 1, 5.00, 9.00, CURDATE() + INTERVAL 1 DAY);

-- T2: CNPJ repetido (UNIQUE)
INSERT INTO estabelecimento (id_usuario, id_endereco, razao_social, nome_fantasia, cnpj, tipo)
VALUES (7, 1, 'Teste Ltda', 'Teste', '11222333000101', 'padaria');

-- T3: doação para excedente inexistente (FK)
INSERT INTO doacao (id_excedente, id_instituicao, quantidade) VALUES (9999, 1, 2.00);

-- T4: status fora da lista (CHECK)
INSERT INTO excedente (id_estabelecimento, id_alimento, quantidade, quantidade_disponivel, data_validade, status)
VALUES (1, 1, 5.00, 5.00, CURDATE() + INTERVAL 1 DAY, 'perdido');

-- T5: previsão para um dia que não é segunda-feira (CHECK)
INSERT INTO previsao_excedente (id_estabelecimento, id_categoria, semana_inicio, kg_previsto)
VALUES (1, 1, '2026-11-11', 10.00);

-- T6: previsão duplicada para a mesma semana (UNIQUE)
INSERT INTO previsao_excedente (id_estabelecimento, id_categoria, semana_inicio, kg_previsto)
SELECT id_estabelecimento, id_categoria, semana_inicio, 1.00 FROM previsao_excedente LIMIT 1;

-- T7: fator de conversão zero (CHECK)
INSERT INTO alimento (id_categoria, nome, unidade_medida, fator_kg) VALUES (1, 'Teste', 'un', 0);
