-- =====================================================================
-- FoodConnect - Checkpoint 3
-- 05 - Usuário da aplicação com privilégio mínimo
-- Troque TROQUE_ESTA_SENHA por uma senha forte antes de rodar.
-- Na Oracle Cloud, troque 'localhost' por '%' (a API roda em outra máquina
-- da mesma rede privada).
-- =====================================================================
CREATE USER IF NOT EXISTS 'foodconnect_app'@'localhost' IDENTIFIED BY 'TROQUE_ESTA_SENHA';
GRANT SELECT, INSERT, UPDATE ON foodconnect_db.* TO 'foodconnect_app'@'localhost';
GRANT EXECUTE ON foodconnect_db.* TO 'foodconnect_app'@'localhost';
-- sem DELETE, DROP, ALTER ou CREATE: a aplicação não apaga dados nem muda a estrutura
