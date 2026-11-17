-- =====================================================================
-- FoodConnect - indicadores por mês (para o gráfico da tela Indicadores)
-- Uma linha por mês: kg ofertados, kg redistribuídos, refeições, doações
-- e a variação em relação ao mês anterior (função de janela LAG).
-- =====================================================================
USE foodconnect_db;

DROP VIEW IF EXISTS vw_indicadores_mensais;
CREATE VIEW vw_indicadores_mensais AS
WITH ofertado AS (
    SELECT DATE_FORMAT(e.data_cadastro, '%Y-%m-01') AS mes,
           SUM(e.quantidade * a.fator_kg)           AS kg_ofertados
      FROM excedente e
      JOIN alimento a ON a.id_alimento = e.id_alimento
     WHERE e.status <> 'cancelado'
     GROUP BY DATE_FORMAT(e.data_cadastro, '%Y-%m-01')
),
retirado AS (
    SELECT DATE_FORMAT(d.data_retirada, '%Y-%m-01') AS mes,
           COUNT(*)                                 AS doacoes,
           SUM(d.quantidade * a.fator_kg)           AS kg_redistribuidos
      FROM doacao d
      JOIN excedente e ON e.id_excedente = d.id_excedente
      JOIN alimento a  ON a.id_alimento = e.id_alimento
     WHERE d.status = 'retirada'
     GROUP BY DATE_FORMAT(d.data_retirada, '%Y-%m-01')
)
SELECT o.mes,
       ROUND(o.kg_ofertados, 1)                        AS kg_ofertados,
       IFNULL(r.doacoes, 0)                            AS doacoes,
       ROUND(IFNULL(r.kg_redistribuidos, 0), 1)        AS kg_redistribuidos,
       ROUND(IFNULL(r.kg_redistribuidos, 0) / 0.5)     AS refeicoes_estimadas,   -- 0,5 kg = 1 refeição
       ROUND(100 * IFNULL(r.kg_redistribuidos, 0) / NULLIF(o.kg_ofertados, 0), 1) AS taxa_aproveitamento,
       ROUND(100 * (IFNULL(r.kg_redistribuidos, 0) - LAG(IFNULL(r.kg_redistribuidos, 0)) OVER (ORDER BY o.mes))
                 / NULLIF(LAG(IFNULL(r.kg_redistribuidos, 0)) OVER (ORDER BY o.mes), 0), 1) AS variacao_pct
  FROM ofertado o
  LEFT JOIN retirado r ON r.mes = o.mes;
