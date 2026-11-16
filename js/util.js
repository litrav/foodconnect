// FoodConnect - funções de apoio (formatação, chamada da API e avisos)

const esc = v => String(v ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const dataBR = s => s ? s.slice(0, 10).split("-").reverse().join("/") : "—";
const num = v => Number(v).toLocaleString("pt-BR", { maximumFractionDigits: 1 });
// sessão fica no sessionStorage: some quando fecha a aba
let sessao = JSON.parse(sessionStorage.getItem("fc_sessao") || "null");
let telaAtual = "excedentes";
let filtroCat = "Todas";

async function api(url, opts = {}) {
  const headers = { "Content-Type": "application/json" };
  if (sessao) headers.Authorization = "Bearer " + sessao.token;
  const r = await fetch(url, { ...opts, headers });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j.erro || "Erro " + r.status);
  return j;
}
function aviso(texto, ok = true) {
  const m = document.getElementById("msg");
  m.textContent = texto; m.className = ok ? "ok" : "erro";
  clearTimeout(m._t); m._t = setTimeout(() => m.className = "", 4000);
}
const C = () => document.getElementById("conteudo");
