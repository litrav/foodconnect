// FoodConnect - menu, navegação entre telas e tela inicial

function desenharMenu() {
  document.body.classList.toggle("na-entrada", telaAtual === "login");
  document.querySelectorAll("#menu a").forEach(a => {
    a.classList.toggle("ativo", a.dataset.tela === telaAtual);
    a.classList.toggle("oculto", !!a.dataset.perfil && (!sessao || sessao.perfil !== a.dataset.perfil));
  });
  document.getElementById("sessao").innerHTML = sessao
    ? `<div class="quem">${esc(sessao.nome)}<small>${PERFIL[sessao.perfil] || ""}</small></div><button onclick="sair()">Sair</button>`
    : `<button onclick="ir('login')">Entrar</button>`;
}
function ir(tela) { telaAtual = tela; desenharMenu(); window.scrollTo(0, 0); TELAS[tela](); }
function sair() { sessao = null; sessionStorage.removeItem("fc_sessao"); ir("login"); }
document.querySelectorAll("#menu a").forEach(a => a.onclick = () => ir(a.dataset.tela));

// quem ainda não entrou começa na tela de login
ir(sessao ? (sessao.perfil === "estabelecimento" ? "cadastrar" : "excedentes") : "login");
