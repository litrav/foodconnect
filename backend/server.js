// =====================================================================
// FoodConnect - API REST (Checkpoint 3)
// Node.js + Express + MySQL 8 (local ou MySQL HeatWave na Oracle Cloud)
// =====================================================================
const express = require("express");
const path = require("path");
const crypto = require("crypto");
const mysql = require("mysql2/promise");
const bcrypt = require("bcryptjs");

for (const v of ["DB_PASS", "TOKEN_SECRET"]) {
  if (!process.env[v]) {
    console.error(`Defina ${v} no arquivo .env (veja .env.example)`);
    process.exit(1);
  }
}

const pool = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || "foodconnect_app",
  password: process.env.DB_PASS,
  database: process.env.DB_NAME || "foodconnect_db",
  dateStrings: true,
  connectionLimit: 10,
});

const app = express();
app.use(express.json({ limit: "20kb" }));
app.use(express.static(path.join(__dirname, "..", "frontend")));

// ---------------------------------------------------------------------
// Autenticação: token assinado com HMAC-SHA256 (válido por 8 horas)
// ---------------------------------------------------------------------
const SECRET = process.env.TOKEN_SECRET;
const b64 = (s) => Buffer.from(s).toString("base64url");
const sign = (data) => crypto.createHmac("sha256", SECRET).update(data).digest("base64url");

function criarToken(payload) {
  const corpo = b64(JSON.stringify({ ...payload, exp: Date.now() + 8 * 3600 * 1000 }));
  return `${corpo}.${sign(corpo)}`;
}

function lerToken(token) {
  const [corpo, assinatura] = String(token || "").split(".");
  if (!corpo || !assinatura) return null;
  const esperado = sign(corpo);
  if (assinatura.length !== esperado.length ||
      !crypto.timingSafeEqual(Buffer.from(assinatura), Buffer.from(esperado))) return null;
  const dados = JSON.parse(Buffer.from(corpo, "base64url").toString());
  return dados.exp > Date.now() ? dados : null;
}

const exigir = (perfil) => (req, res, next) => {
  const u = lerToken((req.headers.authorization || "").replace("Bearer ", ""));
  if (!u) return res.status(401).json({ erro: "Faça login para continuar" });
  if (perfil && u.perfil !== perfil) return res.status(403).json({ erro: "Ação não permitida para este perfil" });
  req.usuario = u;
  next();
};

app.post("/api/login", async (req, res) => {
  const { email, senha } = req.body || {};
  const [[u]] = await pool.query(
    `SELECT u.id_usuario, u.nome, u.perfil, u.senha_hash,
            e.id_estabelecimento, e.nome_fantasia, i.id_instituicao, i.nome AS nome_instituicao
       FROM usuario u
       LEFT JOIN estabelecimento e ON e.id_usuario = u.id_usuario
       LEFT JOIN instituicao i     ON i.id_usuario = u.id_usuario
      WHERE u.email = ? AND u.ativo = TRUE`, [email]);
  if (!u || !(await bcrypt.compare(String(senha || ""), u.senha_hash))) {
    return res.status(401).json({ erro: "E-mail ou senha inválidos" });
  }
  const sessao = {
    id_usuario: u.id_usuario, perfil: u.perfil,
    id_estabelecimento: u.id_estabelecimento, id_instituicao: u.id_instituicao,
    nome: u.nome_fantasia || u.nome_instituicao || u.nome,
  };
  res.json({ token: criarToken(sessao), ...sessao });
});

app.get("/api/login/contas-demo", async (req, res) => {
  const [rows] = await pool.query(
    `SELECT u.email, u.perfil, COALESCE(e.nome_fantasia, i.nome, u.nome) AS nome
       FROM usuario u
       LEFT JOIN estabelecimento e ON e.id_usuario = u.id_usuario
       LEFT JOIN instituicao i     ON i.id_usuario = u.id_usuario
      WHERE u.perfil <> 'admin' ORDER BY u.perfil, nome`);
  res.json(rows);
});

// ---------------------------------------------------------------------
// Consultas públicas
// ---------------------------------------------------------------------
app.get("/api/saude", async (req, res) => {
  const [[r]] = await pool.query("SELECT VERSION() AS mysql, NOW() AS agora");
  res.json({ status: "ok", ...r });
});

app.get("/api/excedentes", async (req, res) => {
  const [rows] = await pool.query("SELECT * FROM vw_excedentes_disponiveis ORDER BY data_validade, id_excedente");
  res.json(rows);
});

app.get("/api/alimentos", async (req, res) => {
  const [rows] = await pool.query(
    `SELECT a.id_alimento, a.nome, a.unidade_medida, c.nome AS categoria
       FROM alimento a JOIN categoria_alimento c ON c.id_categoria = a.id_categoria
      ORDER BY c.nome, a.nome`);
  res.json(rows);
});

app.get("/api/indicadores", async (req, res) => {
  const [[ind]] = await pool.query("SELECT * FROM vw_indicadores");
  res.json(ind);
});

app.get("/api/indicadores/mensal", async (req, res) => {
  const [rows] = await pool.query("SELECT * FROM vw_indicadores_mensais ORDER BY mes");
  res.json(rows);
});

app.get("/api/previsoes", async (req, res) => {
  const [previsao] = await pool.query("SELECT * FROM vw_previsao_semana_atual ORDER BY estabelecimento, categoria");
  const [historico] = await pool.query(
    "SELECT id_estabelecimento, id_categoria, semana_inicio, kg_ofertado FROM vw_excedente_semanal ORDER BY semana_inicio");
  const [acuracia] = await pool.query("SELECT * FROM vw_acuracia_previsao");
  res.json({ previsao, historico, acuracia });
});

// ---------------------------------------------------------------------
// Estabelecimento: cadastrar e acompanhar excedentes
// ---------------------------------------------------------------------
app.post("/api/excedentes", exigir("estabelecimento"), async (req, res) => {
  const { id_alimento, quantidade, data_validade, observacoes } = req.body || {};
  const qtd = Number(quantidade);
  if (!Number.isFinite(qtd) || qtd <= 0) return res.status(400).json({ erro: "Informe uma quantidade maior que zero" });
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(data_validade))) return res.status(400).json({ erro: "Data de validade inválida" });
  try {
    const [r] = await pool.query(
      `INSERT INTO excedente (id_estabelecimento, id_alimento, quantidade, quantidade_disponivel, data_validade, observacoes)
       SELECT ?, ?, ?, ?, ?, ? FROM DUAL WHERE ? >= CURDATE()`,
      [req.usuario.id_estabelecimento, id_alimento, qtd, qtd, data_validade, observacoes || null, data_validade]);
    if (!r.affectedRows) return res.status(400).json({ erro: "A validade não pode estar no passado" });
    res.status(201).json({ id_excedente: r.insertId, status: "disponivel" });
  } catch (e) {
    res.status(400).json({ erro: "Dados inválidos: " + e.sqlMessage });
  }
});

app.get("/api/meus-excedentes", exigir("estabelecimento"), async (req, res) => {
  const [rows] = await pool.query(
    `SELECT e.id_excedente, a.nome AS alimento, e.quantidade, e.quantidade_disponivel, a.unidade_medida,
            e.data_validade, e.status, e.data_cadastro
       FROM excedente e JOIN alimento a ON a.id_alimento = e.id_alimento
      WHERE e.id_estabelecimento = ?
      ORDER BY e.data_cadastro DESC LIMIT 15`, [req.usuario.id_estabelecimento]);
  res.json(rows);
});

// ---------------------------------------------------------------------
// Instituição: solicitar doação (transação) e confirmar retirada
// ---------------------------------------------------------------------
app.post("/api/doacoes", exigir("instituicao"), async (req, res) => {
  const { id_excedente, quantidade } = req.body || {};
  const qtd = Number(quantidade);
  if (!Number.isFinite(qtd) || qtd <= 0) return res.status(400).json({ erro: "Informe uma quantidade maior que zero" });
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    // trava a linha do excedente até o COMMIT: dois pedidos simultâneos não usam o mesmo saldo
    const [[exc]] = await conn.query(
      `SELECT quantidade_disponivel, status, data_validade >= CURDATE() AS dentro_validade
         FROM excedente WHERE id_excedente = ? FOR UPDATE`, [id_excedente]);
    if (!exc || exc.status !== "disponivel" || !exc.dentro_validade || qtd > Number(exc.quantidade_disponivel)) {
      await conn.rollback();
      return res.status(409).json({ erro: "Quantidade indisponível para este excedente" });
    }
    const [r] = await conn.query(
      "INSERT INTO doacao (id_excedente, id_instituicao, quantidade) VALUES (?, ?, ?)",
      [id_excedente, req.usuario.id_instituicao, qtd]);
    await conn.query(
      `UPDATE excedente
          SET quantidade_disponivel = quantidade_disponivel - ?,
              status = IF(quantidade_disponivel = 0, 'reservado', status)
        WHERE id_excedente = ?`, [qtd, id_excedente]);
    await conn.commit();
    res.status(201).json({ id_doacao: r.insertId, status: "solicitada" });
  } catch (e) {
    await conn.rollback();
    res.status(400).json({ erro: "Não foi possível registrar: " + (e.sqlMessage || e.message) });
  } finally {
    conn.release();
  }
});

app.get("/api/minhas-doacoes", exigir("instituicao"), async (req, res) => {
  const [rows] = await pool.query(
    `SELECT d.id_doacao, a.nome AS alimento, est.nome_fantasia AS estabelecimento, en.bairro,
            d.quantidade, a.unidade_medida, d.data_solicitacao, d.data_retirada, d.status
       FROM doacao d
       JOIN excedente e        ON e.id_excedente = d.id_excedente
       JOIN alimento a         ON a.id_alimento = e.id_alimento
       JOIN estabelecimento est ON est.id_estabelecimento = e.id_estabelecimento
       JOIN endereco en        ON en.id_endereco = est.id_endereco
      WHERE d.id_instituicao = ?
      ORDER BY d.data_solicitacao DESC LIMIT 15`, [req.usuario.id_instituicao]);
  res.json(rows);
});

app.patch("/api/doacoes/:id/retirada", exigir("instituicao"), async (req, res) => {
  const [r] = await pool.query(
    `UPDATE doacao SET status = 'retirada', data_retirada = NOW()
      WHERE id_doacao = ? AND id_instituicao = ? AND status IN ('solicitada', 'aprovada')`,
    [req.params.id, req.usuario.id_instituicao]);
  if (!r.affectedRows) return res.status(404).json({ erro: "Doação não encontrada ou já finalizada" });
  res.json({ id_doacao: Number(req.params.id), status: "retirada" });
});

// ---------------------------------------------------------------------
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ erro: "Erro interno" });
});

const PORT = Number(process.env.PORT || 3000);
app.listen(PORT, () => console.log(`FoodConnect API rodando na porta ${PORT}`));
