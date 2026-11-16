-- =====================================================================
-- FoodConnect - Checkpoint 3
-- 01 - Estrutura do banco (DDL), versão final
-- SGBD: MySQL 8.0 (local ou MySQL HeatWave na Oracle Cloud)
-- Autores: Pedro Henrique Trofino Queiroz e João Vitor Dias Freire
-- =====================================================================
-- Mudanças em relação ao CP2:
--   * alimento.fator_kg: converte un/l para kg (indicadores e previsão em kg)
--   * nova tabela previsao_excedente (análise preditiva)
--   * novos índices para consultas históricas
--   * views de histórico semanal, previsão e acurácia
--   * procedures de previsão e de vencimento, evento diário
-- =====================================================================

DROP DATABASE IF EXISTS foodconnect_db;
CREATE DATABASE foodconnect_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE foodconnect_db;
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- Cadastros
-- ---------------------------------------------------------------------
CREATE TABLE usuario (
    id_usuario    INT AUTO_INCREMENT PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    senha_hash    VARCHAR(255) NOT NULL,              -- somente hash (bcrypt), nunca a senha
    telefone      VARCHAR(15),
    perfil        VARCHAR(15)  NOT NULL,
    ativo         BOOLEAN      NOT NULL DEFAULT TRUE,
    data_cadastro DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_usuario_perfil CHECK (perfil IN ('estabelecimento', 'instituicao', 'admin'))
);

CREATE TABLE endereco (
    id_endereco INT AUTO_INCREMENT PRIMARY KEY,
    logradouro  VARCHAR(100)  NOT NULL,
    numero      VARCHAR(10)   NOT NULL,
    complemento VARCHAR(50),
    bairro      VARCHAR(60)   NOT NULL,
    cidade      VARCHAR(60)   NOT NULL DEFAULT 'São Paulo',
    uf          CHAR(2)       NOT NULL DEFAULT 'SP',
    cep         CHAR(8)       NOT NULL,
    latitude    DECIMAL(9,6),
    longitude   DECIMAL(9,6),
    CONSTRAINT chk_endereco_cep CHECK (cep REGEXP '^[0-9]{8}$')
);

CREATE TABLE estabelecimento (
    id_estabelecimento INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario         INT          NOT NULL UNIQUE,    -- 1:1 com usuario
    id_endereco        INT          NOT NULL,
    razao_social       VARCHAR(120) NOT NULL,
    nome_fantasia      VARCHAR(100) NOT NULL,
    cnpj               CHAR(14)     NOT NULL UNIQUE,
    tipo               VARCHAR(15)  NOT NULL,
    CONSTRAINT chk_estabelecimento_tipo CHECK (tipo IN ('restaurante', 'supermercado', 'padaria', 'outro')),
    CONSTRAINT fk_estabelecimento_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario (id_usuario),
    CONSTRAINT fk_estabelecimento_endereco FOREIGN KEY (id_endereco)
        REFERENCES endereco (id_endereco)
);

CREATE TABLE instituicao (
    id_instituicao    INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario        INT          NOT NULL UNIQUE,     -- 1:1 com usuario
    id_endereco       INT          NOT NULL,
    nome              VARCHAR(120) NOT NULL,
    cnpj              CHAR(14)     NOT NULL UNIQUE,
    tipo              VARCHAR(20)  NOT NULL,
    capacidade_kg_dia DECIMAL(8,2) NOT NULL,
    pessoas_atendidas INT          NOT NULL DEFAULT 0,
    CONSTRAINT chk_instituicao_tipo CHECK (tipo IN ('ong', 'abrigo', 'banco_alimentos', 'outro')),
    CONSTRAINT chk_instituicao_capacidade CHECK (capacidade_kg_dia > 0),
    CONSTRAINT chk_instituicao_pessoas CHECK (pessoas_atendidas >= 0),
    CONSTRAINT fk_instituicao_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario (id_usuario),
    CONSTRAINT fk_instituicao_endereco FOREIGN KEY (id_endereco)
        REFERENCES endereco (id_endereco)
);

CREATE TABLE categoria_alimento (
    id_categoria        INT AUTO_INCREMENT PRIMARY KEY,
    nome                VARCHAR(50)  NOT NULL UNIQUE,
    descricao           VARCHAR(255),
    requer_refrigeracao BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE TABLE alimento (
    id_alimento    INT AUTO_INCREMENT PRIMARY KEY,
    id_categoria   INT          NOT NULL,
    nome           VARCHAR(100) NOT NULL,
    unidade_medida VARCHAR(5)   NOT NULL,
    fator_kg       DECIMAL(6,3) NOT NULL DEFAULT 1.000,  -- quantos kg vale 1 unidade (NOVO no CP3)
    CONSTRAINT uq_alimento_nome UNIQUE (id_categoria, nome),
    CONSTRAINT chk_alimento_unidade CHECK (unidade_medida IN ('kg', 'un', 'l')),
    CONSTRAINT chk_alimento_fator CHECK (fator_kg > 0),
    CONSTRAINT fk_alimento_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria_alimento (id_categoria)
);

-- ---------------------------------------------------------------------
-- Núcleo do sistema
-- ---------------------------------------------------------------------
CREATE TABLE excedente (
    id_excedente          INT AUTO_INCREMENT PRIMARY KEY,
    id_estabelecimento    INT          NOT NULL,
    id_alimento           INT          NOT NULL,
    quantidade            DECIMAL(8,2) NOT NULL,
    quantidade_disponivel DECIMAL(8,2) NOT NULL,
    data_validade         DATE         NOT NULL,
    data_cadastro         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status                VARCHAR(12)  NOT NULL DEFAULT 'disponivel',
    observacoes           VARCHAR(255),
    CONSTRAINT chk_excedente_quantidade CHECK (quantidade > 0),
    CONSTRAINT chk_excedente_disponivel CHECK (quantidade_disponivel BETWEEN 0 AND quantidade),
    CONSTRAINT chk_excedente_status CHECK (status IN ('disponivel', 'reservado', 'esgotado', 'vencido', 'cancelado')),
    CONSTRAINT fk_excedente_estabelecimento FOREIGN KEY (id_estabelecimento)
        REFERENCES estabelecimento (id_estabelecimento),
    CONSTRAINT fk_excedente_alimento FOREIGN KEY (id_alimento)
        REFERENCES alimento (id_alimento)
);

-- N:N entre excedente e instituicao
CREATE TABLE doacao (
    id_doacao        INT AUTO_INCREMENT PRIMARY KEY,
    id_excedente     INT          NOT NULL,
    id_instituicao   INT          NOT NULL,
    quantidade       DECIMAL(8,2) NOT NULL,
    data_solicitacao DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_retirada    DATETIME,
    status           VARCHAR(12)  NOT NULL DEFAULT 'solicitada',
    CONSTRAINT chk_doacao_quantidade CHECK (quantidade > 0),
    CONSTRAINT chk_doacao_status CHECK (status IN ('solicitada', 'aprovada', 'retirada', 'cancelada')),
    CONSTRAINT fk_doacao_excedente FOREIGN KEY (id_excedente)
        REFERENCES excedente (id_excedente),
    CONSTRAINT fk_doacao_instituicao FOREIGN KEY (id_instituicao)
        REFERENCES instituicao (id_instituicao)
);

-- ---------------------------------------------------------------------
-- Análise preditiva (NOVO no CP3)
-- Guarda a previsão de kg de excedente por estabelecimento e categoria
-- para uma semana, e depois o valor real, para medir o erro.
-- ---------------------------------------------------------------------
CREATE TABLE previsao_excedente (
    id_previsao        INT AUTO_INCREMENT PRIMARY KEY,
    id_estabelecimento INT          NOT NULL,
    id_categoria       INT          NOT NULL,
    semana_inicio      DATE         NOT NULL,           -- segunda-feira da semana prevista
    kg_previsto        DECIMAL(8,2) NOT NULL,
    kg_real            DECIMAL(8,2),                    -- preenchido quando a semana termina
    metodo             VARCHAR(40)  NOT NULL DEFAULT 'media_movel_ponderada_4s',
    data_geracao       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_previsao UNIQUE (id_estabelecimento, id_categoria, semana_inicio),
    CONSTRAINT chk_previsao_kg CHECK (kg_previsto >= 0 AND (kg_real IS NULL OR kg_real >= 0)),
    CONSTRAINT chk_previsao_segunda CHECK (WEEKDAY(semana_inicio) = 0),
    CONSTRAINT fk_previsao_estabelecimento FOREIGN KEY (id_estabelecimento)
        REFERENCES estabelecimento (id_estabelecimento),
    CONSTRAINT fk_previsao_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria_alimento (id_categoria)
);

-- ---------------------------------------------------------------------
-- Índices
-- ---------------------------------------------------------------------
CREATE INDEX idx_excedente_status_validade ON excedente (status, data_validade);
CREATE INDEX idx_excedente_est_cadastro   ON excedente (id_estabelecimento, data_cadastro);
CREATE INDEX idx_doacao_instituicao_status ON doacao (id_instituicao, status);

-- ---------------------------------------------------------------------
-- Views operacionais
-- ---------------------------------------------------------------------
CREATE VIEW vw_excedentes_disponiveis AS
SELECT e.id_excedente, est.id_estabelecimento, est.nome_fantasia AS estabelecimento,
       en.bairro, en.latitude, en.longitude,
       a.nome AS alimento, c.nome AS categoria, c.requer_refrigeracao,
       e.quantidade_disponivel, a.unidade_medida,
       ROUND(e.quantidade_disponivel * a.fator_kg, 2) AS kg_disponivel,
       e.data_validade, DATEDIFF(e.data_validade, CURDATE()) AS dias_para_vencer
FROM excedente e
JOIN estabelecimento est ON est.id_estabelecimento = e.id_estabelecimento
JOIN endereco en         ON en.id_endereco = est.id_endereco
JOIN alimento a          ON a.id_alimento = e.id_alimento
JOIN categoria_alimento c ON c.id_categoria = a.id_categoria
WHERE e.status = 'disponivel'
  AND e.quantidade_disponivel > 0
  AND e.data_validade >= CURDATE();

CREATE VIEW vw_indicadores AS
SELECT
  (SELECT IFNULL(ROUND(SUM(d.quantidade * a.fator_kg), 1), 0)
     FROM doacao d
     JOIN excedente e ON e.id_excedente = d.id_excedente
     JOIN alimento a  ON a.id_alimento = e.id_alimento
    WHERE d.status = 'retirada')                                   AS kg_redistribuidos,
  (SELECT ROUND(100 * SUM((e.quantidade - e.quantidade_disponivel) * a.fator_kg)
                    / NULLIF(SUM(e.quantidade * a.fator_kg), 0), 1)
     FROM excedente e
     JOIN alimento a ON a.id_alimento = e.id_alimento
    WHERE e.status <> 'cancelado')                                 AS taxa_aproveitamento,
  (SELECT COUNT(*) FROM doacao WHERE status <> 'cancelada')        AS total_doacoes,
  (SELECT COUNT(*) FROM vw_excedentes_disponiveis)                 AS excedentes_disponiveis,
  (SELECT COUNT(*) FROM excedente WHERE status = 'vencido')        AS excedentes_vencidos,
  (SELECT IFNULL(ROUND(SUM(d.quantidade * a.fator_kg) / 0.5), 0)   -- 0,5 kg ≈ 1 refeição
     FROM doacao d
     JOIN excedente e ON e.id_excedente = d.id_excedente
     JOIN alimento a  ON a.id_alimento = e.id_alimento
    WHERE d.status = 'retirada')                                   AS refeicoes_estimadas;

-- ---------------------------------------------------------------------
-- Views de análise preditiva
-- ---------------------------------------------------------------------

-- kg ofertados por estabelecimento, categoria e semana (últimas 12 semanas
-- fechadas). Semanas sem oferta entram com zero, graças ao calendário (CTE).
CREATE VIEW vw_excedente_semanal AS
WITH RECURSIVE semanas (n, semana_inicio) AS (
    SELECT 1, CURDATE() - INTERVAL (WEEKDAY(CURDATE()) + 7) DAY
    UNION ALL
    SELECT n + 1, semana_inicio - INTERVAL 7 DAY FROM semanas WHERE n < 12
),
pares AS (
    SELECT DISTINCT e.id_estabelecimento, a.id_categoria
    FROM excedente e JOIN alimento a ON a.id_alimento = e.id_alimento
),
oferta AS (
    SELECT e.id_estabelecimento, a.id_categoria,
           DATE(e.data_cadastro) - INTERVAL WEEKDAY(e.data_cadastro) DAY AS semana_inicio,
           SUM(e.quantidade * a.fator_kg) AS kg
    FROM excedente e JOIN alimento a ON a.id_alimento = e.id_alimento
    WHERE e.status <> 'cancelado'
    GROUP BY e.id_estabelecimento, a.id_categoria, semana_inicio
)
SELECT p.id_estabelecimento, p.id_categoria, s.semana_inicio,
       ROUND(IFNULL(o.kg, 0), 2) AS kg_ofertado
FROM pares p
CROSS JOIN semanas s
LEFT JOIN oferta o ON o.id_estabelecimento = p.id_estabelecimento
                  AND o.id_categoria = p.id_categoria
                  AND o.semana_inicio = s.semana_inicio;

-- Para cada semana do histórico: a previsão que o método teria feito
-- (média móvel ponderada das 4 semanas anteriores, pesos 4-3-2-1)
-- e o erro em relação ao valor real. Usa funções de janela (LAG).
CREATE VIEW vw_backtest_previsao AS
SELECT id_estabelecimento, id_categoria, semana_inicio, kg_ofertado AS kg_real,
       ROUND((4 * s1 + 3 * s2 + 2 * s3 + 1 * s4) / 10, 2)                       AS kg_previsto,
       ROUND(ABS(kg_ofertado - (4 * s1 + 3 * s2 + 2 * s3 + 1 * s4) / 10), 2)   AS erro_abs_kg
FROM (
    SELECT id_estabelecimento, id_categoria, semana_inicio, kg_ofertado,
           LAG(kg_ofertado, 1) OVER w AS s1,
           LAG(kg_ofertado, 2) OVER w AS s2,
           LAG(kg_ofertado, 3) OVER w AS s3,
           LAG(kg_ofertado, 4) OVER w AS s4
    FROM vw_excedente_semanal
    WINDOW w AS (PARTITION BY id_estabelecimento, id_categoria ORDER BY semana_inicio)
) t
WHERE s4 IS NOT NULL;

-- Acurácia do método por estabelecimento e categoria
CREATE VIEW vw_acuracia_previsao AS
SELECT b.id_estabelecimento, est.nome_fantasia AS estabelecimento,
       b.id_categoria, c.nome AS categoria,
       COUNT(*)                                                   AS semanas_testadas,
       ROUND(AVG(b.erro_abs_kg), 2)                               AS erro_medio_kg,
       ROUND(100 * SUM(b.erro_abs_kg) / NULLIF(SUM(b.kg_real), 0), 1) AS erro_percentual
FROM vw_backtest_previsao b
JOIN estabelecimento est   ON est.id_estabelecimento = b.id_estabelecimento
JOIN categoria_alimento c  ON c.id_categoria = b.id_categoria
GROUP BY b.id_estabelecimento, est.nome_fantasia, b.id_categoria, c.nome;

-- Previsão para a semana atual (segunda-feira desta semana).
-- Tendência: média das 4 últimas semanas comparada com as 4 anteriores.
CREATE VIEW vw_previsao_semana_atual AS
SELECT t.id_estabelecimento, est.nome_fantasia AS estabelecimento,
       t.id_categoria, c.nome AS categoria, c.requer_refrigeracao,
       CURDATE() - INTERVAL WEEKDAY(CURDATE()) DAY                    AS semana_inicio,
       ROUND((4 * t.s1 + 3 * t.s2 + 2 * t.s3 + 1 * t.s4) / 10, 2)     AS kg_previsto,
       ROUND(t.media_recente, 2)                                      AS media_4_semanas,
       ROUND(100 * (t.media_recente - t.media_anterior) / NULLIF(t.media_anterior, 0), 1) AS variacao_pct,
       CASE
         WHEN t.media_recente > 1.10 * t.media_anterior THEN 'alta'
         WHEN t.media_recente < 0.90 * t.media_anterior THEN 'queda'
         ELSE 'estavel'
       END                                                            AS tendencia
FROM (
    SELECT id_estabelecimento, id_categoria,
           SUM(CASE WHEN rk = 1 THEN kg_ofertado END) AS s1,
           SUM(CASE WHEN rk = 2 THEN kg_ofertado END) AS s2,
           SUM(CASE WHEN rk = 3 THEN kg_ofertado END) AS s3,
           SUM(CASE WHEN rk = 4 THEN kg_ofertado END) AS s4,
           AVG(CASE WHEN rk BETWEEN 1 AND 4 THEN kg_ofertado END) AS media_recente,
           AVG(CASE WHEN rk BETWEEN 5 AND 8 THEN kg_ofertado END) AS media_anterior
    FROM (
        SELECT id_estabelecimento, id_categoria, kg_ofertado,
               ROW_NUMBER() OVER (PARTITION BY id_estabelecimento, id_categoria
                                  ORDER BY semana_inicio DESC) AS rk
        FROM vw_excedente_semanal
    ) ult
    WHERE rk <= 8
    GROUP BY id_estabelecimento, id_categoria
) t
JOIN estabelecimento est  ON est.id_estabelecimento = t.id_estabelecimento
JOIN categoria_alimento c ON c.id_categoria = t.id_categoria;

-- ---------------------------------------------------------------------
-- Procedures e evento
-- ---------------------------------------------------------------------
DELIMITER $$

-- Grava (ou atualiza) a previsão da semana atual e preenche o valor real
-- das previsões de semanas que já terminaram.
CREATE PROCEDURE sp_gerar_previsoes()
BEGIN
    INSERT INTO previsao_excedente (id_estabelecimento, id_categoria, semana_inicio, kg_previsto)
    SELECT id_estabelecimento, id_categoria, semana_inicio, kg_previsto
    FROM vw_previsao_semana_atual
    ON DUPLICATE KEY UPDATE kg_previsto = VALUES(kg_previsto), data_geracao = NOW();

    UPDATE previsao_excedente p
    JOIN vw_excedente_semanal s
      ON s.id_estabelecimento = p.id_estabelecimento
     AND s.id_categoria = p.id_categoria
     AND s.semana_inicio = p.semana_inicio
    SET p.kg_real = s.kg_ofertado
    WHERE p.kg_real IS NULL;
END$$

-- Marca como vencido o excedente disponível que passou da validade.
CREATE PROCEDURE sp_atualizar_vencidos()
BEGIN
    UPDATE excedente
       SET status = 'vencido'
     WHERE status = 'disponivel'
       AND data_validade < CURDATE();
END$$

CREATE EVENT IF NOT EXISTS ev_rotina_diaria
    ON SCHEDULE EVERY 1 DAY STARTS (CURDATE() + INTERVAL 1 DAY + INTERVAL 1 HOUR)
    DO BEGIN
        CALL sp_atualizar_vencidos();
        CALL sp_gerar_previsoes();
    END$$

DELIMITER ;
