// FoodConnect - ações dos botões (entrar, cadastrar, solicitar, confirmar retirada)

function usarConta(email) {
  document.getElementById("usuario").value = email;
  document.getElementById("senha").focus();
}
async function entrar() {
  const email = document.getElementById("usuario").value.trim();
  const senha = document.getElementById("senha").value;
  if (!email || !senha) return aviso("Digite o usuário e a senha.", false);
  try {
    sessao = await api("/api/login", { method: "POST",
      body: JSON.stringify({ email, senha }) });
    sessionStorage.setItem("fc_sessao", JSON.stringify(sessao));
    aviso("Bem-vindo(a), " + sessao.nome + "!");
    ir(sessao.perfil === "estabelecimento" ? "cadastrar" : "excedentes");
  } catch (e) { aviso(e.message, false); }
}
async function solicitar(id) {
  try {
    const j = await api("/api/doacoes", { method: "POST",
      body: JSON.stringify({ id_excedente: id, quantidade: Number(document.getElementById("qtd" + id).value) }) });
    aviso(`Doação nº ${j.id_doacao} solicitada (status: ${j.status}).`);
  } catch (e) { aviso(e.message, false); }
  TELAS.excedentes();
}
async function cadastrar() {
  try {
    const j = await api("/api/excedentes", { method: "POST", body: JSON.stringify({
      id_alimento: Number(document.getElementById("alimento").value),
      quantidade: Number(document.getElementById("quantidade").value),
      data_validade: document.getElementById("validade").value,
      observacoes: document.getElementById("obs").value }) });
    aviso(`Excedente nº ${j.id_excedente} cadastrado e já disponível para as instituições.`);
    ir("meus");
  } catch (e) { aviso(e.message, false); }
}
async function retirar(id) {
  try { await api(`/api/doacoes/${id}/retirada`, { method: "PATCH" }); aviso("Retirada confirmada."); }
  catch (e) { aviso(e.message, false); }
  TELAS.doacoes();
}
