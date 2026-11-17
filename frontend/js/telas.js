// FoodConnect - cada tela do site é uma função que desenha o conteúdo do <main>

const ICONE = {
  estabelecimento: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 9l1.5-5h15L21 9"/><path d="M4 9v11h16V9"/><path d="M3 9h18"/><path d="M10 20v-5h4v5"/></svg>',
  instituicao: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 21s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 11c0 5.5-7 10-7 10z"/></svg>'
};
const PERFIL = { estabelecimento: "Estabelecimento doador", instituicao: "Instituição", admin: "Administrador" };

const TELAS = {
  async login() {
    const [contas, ind] = await Promise.all([api("/api/login/contas-demo").catch(() => []), api("/api/indicadores").catch(() => null)]);
    C().innerHTML = `<div class="entrada">
      <section class="lado">
        <div class="marca"><img src="img/logo.svg" width="34" height="34" alt="">FoodConnect</div>
        <div><h1>Comida boa não vai para o lixo.</h1>
          <p>Restaurantes, padarias e mercados avisam o que sobrou no dia. ONGs e abrigos da região pedem e retiram.</p>
          <p><a class="ver-video" onclick="ir('porque')">▶ Veja por que isso importa</a></p></div>
        ${ind ? `<div class="impacto">Até agora, <b>${num(ind.kg_redistribuidos)} kg</b> de alimento chegaram a quem precisa, cerca de <b>${num(ind.refeicoes_estimadas)}</b> refeições.</div>` : "<div></div>"}
        <svg class="prato" width="420" height="420" viewBox="0 0 32 32" aria-hidden="true"><circle cx="16" cy="16" r="14" fill="none" stroke="#fff" stroke-width="1.2"/><circle cx="16" cy="16" r="9" fill="none" stroke="#fff" stroke-width="1.2"/></svg>
      </section>
      <section class="form-entrada">
        <h2>Entrar</h2>
        <p class="sub">Use o e-mail e a senha da sua conta.</p>
        <form onsubmit="entrar(); return false">
          <div class="campo"><label for="usuario">Usuário (e-mail)</label>
            <input id="usuario" type="email" autocomplete="username" placeholder="nome@exemplo.com.br" required></div>
          <div class="campo"><label for="senha">Senha</label>
            <input id="senha" type="password" autocomplete="current-password" required></div>
          <button type="submit" class="grande">Entrar</button>
        </form>
        ${contas.length ? `<details class="demo"><summary>Contas de demonstração</summary>
          <p>Clique em uma conta para preencher o usuário. A senha é a de demonstração.</p>
          ${contas.map(c => `<button type="button" class="chip" data-email="${esc(c.email)}" onclick="usarConta(this.dataset.email)">
            ${ICONE[c.perfil] || ""}${esc(c.nome)}<small>${c.perfil === "estabelecimento" ? "doa" : "recebe"}</small></button>`).join("")}
        </details>` : ""}
        <p class="so-olhar">Só quer ver o que está disponível? <a onclick="ir('excedentes')">Ver excedentes sem entrar</a></p>
      </section></div>`;
  },

  async excedentes() {
    const exc = await api("/api/excedentes");
    const podePedir = sessao && sessao.perfil === "instituicao";
    const cats = ["Todas", ...new Set(exc.map(e => e.categoria))];
    if (!cats.includes(filtroCat)) filtroCat = "Todas";
    const lista = exc.filter(e => filtroCat === "Todas" || e.categoria === filtroCat);
    const vence = d => d <= 0 ? "vence hoje" : d === 1 ? "vence amanhã" : "";
    C().innerHTML = `<div class="cabeca"><div><h2>Excedentes disponíveis</h2>
        <p class="sub">${podePedir ? "Escolha a quantidade e solicite para " + esc(sessao.nome) + "."
          : sessao ? "Estes são os alimentos que as instituições podem pedir agora."
          : "Entre como instituição para solicitar uma doação."}</p></div>
        <div class="sub">${lista.length} ${lista.length === 1 ? "alimento" : "alimentos"}</div></div>
      <div class="filtros">${cats.map(c => `<button class="${c === filtroCat ? "on" : ""}" data-c="${esc(c)}" onclick="filtroCat=this.dataset.c;TELAS.excedentes()">${esc(c)}</button>`).join("")}</div>
      <section class="grid">${lista.map(e => `
        <article class="exc">
          <div class="topo-card"><span class="cat">${esc(e.categoria)}</span><span class="selos">
            ${e.requer_refrigeracao ? '<span class="selo frio">refrigerado</span>' : ""}
            ${e.dias_para_vencer <= 1 ? `<span class="selo urgente">${vence(e.dias_para_vencer)}</span>` : ""}</span></div>
          <h3>${esc(e.alimento)}</h3>
          <div class="origem">${esc(e.estabelecimento)}, ${esc(e.bairro)}</div>
          <div class="qtd"><b>${num(e.quantidade_disponivel)} ${e.unidade_medida}</b>${e.unidade_medida === "kg" ? "" : `<span>≈ ${num(e.kg_disponivel)} kg</span>`}</div>
          <div class="validade">Validade: ${dataBR(e.data_validade)}</div>
          ${podePedir ? `<div class="pedir">
            <input id="qtd${e.id_excedente}" type="number" min="1" step="1" value="1" aria-label="Quantidade de ${esc(e.alimento)}">
            <button onclick="solicitar(${e.id_excedente})">Solicitar</button></div>` : ""}
        </article>`).join("") || '<div class="vazio">Nenhum excedente disponível agora. Quando um estabelecimento cadastrar uma sobra, ela aparece aqui.</div>'}</section>`;
  },

  async cadastrar() {
    const alimentos = await api("/api/alimentos");
    const amanha = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
    C().innerHTML = `<div class="cabeca"><div><h2>Cadastrar excedente</h2><p class="sub">${esc(sessao.nome)}: informe o que sobrou hoje.</p></div></div>
      <div class="duas"><div class="painel"><div class="form">
        <div class="full"><label for="alimento">Alimento</label><select id="alimento">${alimentos.map(a =>
          `<option value="${a.id_alimento}">${esc(a.categoria)} · ${esc(a.nome)} (${a.unidade_medida})</option>`).join("")}</select></div>
        <div><label for="quantidade">Quantidade</label><input id="quantidade" type="number" min="0.5" step="0.5" value="5"></div>
        <div><label for="validade">Validade</label><input id="validade" type="date" value="${amanha}"></div>
        <div class="full"><label for="obs">Observações</label><textarea id="obs" rows="3" placeholder="Ex.: retirar até 21h"></textarea></div>
        <div class="full"><button onclick="cadastrar()">Cadastrar excedente</button></div>
      </div></div>
      <aside class="dica"><h3>O que acontece depois</h3><ol>
        <li>O alimento aparece na hora para as instituições.</li>
        <li>Uma instituição pede a quantidade que precisa.</li>
        <li>Ela vem buscar e confirma a retirada no sistema.</li></ol></aside></div>`;
  },

  async meus() {
    const rows = await api("/api/meus-excedentes");
    C().innerHTML = `<div class="cabeca"><div><h2>Meus excedentes</h2><p class="sub">Últimos cadastros de ${esc(sessao.nome)}.</p></div>
        <button class="sec" onclick="ir('cadastrar')">Cadastrar excedente</button></div>
      <div class="tabela"><table><tr><th>Alimento</th><th>Quantidade</th><th>Disponível</th><th>Validade</th><th>Status</th></tr>
      ${rows.map(r => `<tr><td><b>${esc(r.alimento)}</b></td><td>${num(r.quantidade)} ${r.unidade_medida}</td>
        <td>${num(r.quantidade_disponivel)} ${r.unidade_medida}</td><td>${dataBR(r.data_validade)}</td>
        <td><span class="st ${r.status}">${r.status}</span></td></tr>`).join("")}</table></div>`;
  },

  async doacoes() {
    const rows = await api("/api/minhas-doacoes");
    C().innerHTML = `<div class="cabeca"><div><h2>Minhas doações</h2><p class="sub">Pedidos de ${esc(sessao.nome)}. Confirme quando retirar.</p></div>
        <button class="sec" onclick="ir('excedentes')">Pedir mais alimentos</button></div>
      <div class="tabela"><table><tr><th>Alimento</th><th>Estabelecimento</th><th>Quantidade</th><th>Solicitada em</th><th>Status</th><th></th></tr>
      ${rows.map(r => `<tr><td><b>${esc(r.alimento)}</b></td><td>${esc(r.estabelecimento)}, ${esc(r.bairro)}</td>
        <td>${num(r.quantidade)} ${r.unidade_medida}</td><td>${dataBR(r.data_solicitacao)}</td>
        <td><span class="st ${r.status}">${r.status}</span></td>
        <td>${["solicitada", "aprovada"].includes(r.status)
              ? `<button class="sec" onclick="retirar(${r.id_doacao})">Confirmar retirada</button>` : ""}</td></tr>`).join("")}</table></div>`;
  },

  async indicadores() {
    const [i, meses] = await Promise.all([api("/api/indicadores"), api("/api/indicadores/mensal").catch(() => [])]);
    C().innerHTML = `<div class="cabeca"><div><h2>Indicadores de impacto</h2><p class="sub">Calculados em tempo real a partir das doações registradas.</p></div></div>
      <section class="kpis">${[
        [num(i.kg_redistribuidos) + " kg", "de alimento redistribuído", "destaque"],
        [num(i.refeicoes_estimadas), "refeições estimadas (0,5 kg cada)", "destaque"],
        [num(i.taxa_aproveitamento) + "%", "dos excedentes aproveitados", "destaque"],
        [i.total_doacoes, "doações registradas", ""],
        [i.excedentes_disponiveis, "excedentes disponíveis agora", ""],
        [i.excedentes_vencidos, "excedentes que venceram sem retirada", "alerta"],
      ].map(([v, l, c]) => `<div class="kpi ${c}"><b>${v}</b><span>${l}</span></div>`).join("")}</section>
      ${meses.length ? `<section class="mensal">
        <div class="cabeca"><div><h3>Mês a mês</h3><p class="sub">Compare o resultado de cada mês.</p></div>
          <div class="filtros" id="metricas">${Object.entries(METRICAS).map(([k, m]) =>
            `<button data-m="${k}" class="${k === metricaMensal ? "on" : ""}" onclick="trocarMetrica(this.dataset.m)">${m.rotulo}</button>`).join("")}</div></div>
        <div class="painel" id="grafico-mensal"></div>
        <div class="tabela"><table><tr><th>Mês</th><th>Alimento ofertado</th><th>Alimento redistribuído</th><th>Refeições</th><th>Doações</th><th>Aproveitamento</th><th>Em relação ao mês anterior</th></tr>
          ${meses.map((m, k) => `<tr><td><b>${nomeMes(m.mes, true)}</b>${k === meses.length - 1 ? ' <span class="st">em andamento</span>' : ""}</td>
            <td>${num(m.kg_ofertados)} kg</td><td>${num(m.kg_redistribuidos)} kg</td><td>${num(m.refeicoes_estimadas)}</td>
            <td>${m.doacoes}</td><td>${num(m.taxa_aproveitamento)}%</td>
            <td>${m.variacao_pct === null ? "—" : `<span class="tend ${m.variacao_pct >= 0 ? "alta" : "queda"}">${m.variacao_pct >= 0 ? "▲ +" : "▼ "}${num(m.variacao_pct)}%</span>`}</td></tr>`).join("")}
        </table></div>
        <p class="nota">Histórico: dados de teste simulados. O primeiro e o último mês estão incompletos.</p>
      </section>` : ""}`;
    dadosMensais = meses;
    if (meses.length) desenharMensal();
  },

  porque() {
    C().innerHTML = `<div class="cabeca"><div><h2>Por que o FoodConnect existe</h2>
        <p class="sub">Sobra comida de um lado e falta do outro. O problema não é a quantidade de alimento, é fazer ele chegar.</p></div></div>
      <section class="fatos">${FATOS.map(f => `<div class="kpi destaque"><b>${f.numero}</b><span>${f.texto}</span></div>`).join("")}</section>
      <p class="nota" style="margin:10px 0 26px">Fonte: <a href="${FONTE_FATOS.link}" target="_blank" rel="noopener">${FONTE_FATOS.texto}</a></p>
      <section class="videos">${VIDEOS.map(v => `<article class="video">
        <div class="quadro"><iframe src="https://www.youtube-nocookie.com/embed/${v.id}?rel=0" title="${esc(v.titulo)}" loading="lazy"
          allow="accelerometer; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe></div>
        <h3>${esc(v.titulo)}</h3><div class="origem">${esc(v.fonte)}</div><p>${esc(v.texto)}</p>
        <a href="https://www.youtube.com/watch?v=${v.id}" target="_blank" rel="noopener">Abrir no YouTube</a></article>`).join("")}</section>
      <div class="chamada"><div><h3>O que dá para fazer</h3>
        <p>Cada quilo cadastrado aqui é um quilo que deixa de ir para o lixo e vira refeição.</p></div>
        <button onclick="ir(sessao ? 'excedentes' : 'login')">${sessao ? "Ver excedentes disponíveis" : "Entrar no FoodConnect"}</button></div>`;
  },

  async previsao() {
    const { previsao, historico, acuracia } = await api("/api/previsoes");
    const erro = Object.fromEntries(acuracia.map(a => [a.id_estabelecimento + "-" + a.id_categoria, a.erro_percentual]));
    C().innerHTML = `<div class="cabeca"><div><h2>Previsão de excedentes para esta semana</h2>
      <p class="sub">Média móvel ponderada das 4 últimas semanas (pesos 4, 3, 2 e 1), calculada no banco de dados.</p></div></div>
      <div class="legenda"><span><i></i>kg ofertados por semana</span><span><i class="p"></i>previsão</span></div>
      <section class="prev">${previsao.map(p => {
        const serie = historico.filter(h => h.id_estabelecimento === p.id_estabelecimento && h.id_categoria === p.id_categoria);
        return `<div class="card"><div class="linha"><span class="cat">${esc(p.categoria)}</span>
          <span class="tend ${p.tendencia}">${{alta: "▲ alta", queda: "▼ queda", estavel: "● estável"}[p.tendencia]} ${p.variacao_pct > 0 ? "+" : ""}${num(p.variacao_pct)}%</span></div>
          <h3>${esc(p.estabelecimento)}</h3>
          <div class="linha">
            <div><div class="num">${num(p.kg_previsto)} kg</div><div class="meta" style="margin:2px 0 0">previstos para a semana de ${dataBR(p.semana_inicio)}</div></div>
            ${grafico(serie, Number(p.kg_previsto))}
          </div>
          <div class="meta">Erro médio do método nas últimas 8 semanas: <b>${num(erro[p.id_estabelecimento + "-" + p.id_categoria])}%</b></div>
        </div>`; }).join("")}</section>
      <p class="nota">Para que serve: as instituições conseguem planejar retiradas e espaço de armazenamento antes de o alimento ser ofertado.
        Histórico das 12 semanas anteriores: dados de teste simulados.</p>`;
  },
};

// mini gráfico da tela de previsão: histórico (verde) + previsão (laranja)
function grafico(serie, previsto) {
  const vals = serie.map(s => Number(s.kg_ofertado)).concat(previsto);
  const W = 230, H = 80, max = Math.max(...vals) * 1.1, n = vals.length;
  const x = i => 6 + i * (W - 12) / (n - 1), y = v => H - 6 - v * (H - 12) / max;
  const pts = vals.slice(0, -1).map((v, i) => `${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" ");
  return `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" aria-label="histórico semanal e previsão" style="max-width:48%">
    <polyline points="${pts}" fill="none" stroke="#3E8E4F" stroke-width="2.2" stroke-linejoin="round"/>
    <line x1="${x(n - 2)}" y1="${y(vals[n - 2])}" x2="${x(n - 1)}" y2="${y(previsto)}" stroke="#C7802F" stroke-width="2.2" stroke-dasharray="4 3"/>
    <circle cx="${x(n - 1)}" cy="${y(previsto)}" r="4.5" fill="#C7802F"/></svg>`;
}

// ---------- gráfico de barras "mês a mês" da tela de indicadores
const METRICAS = {
  kg_redistribuidos:   { rotulo: "Alimento (kg)", unidade: " kg", cor: "#3E8E4F" },
  refeicoes_estimadas: { rotulo: "Refeições",     unidade: "",    cor: "#C7802F" },
  doacoes:             { rotulo: "Doações",       unidade: "",    cor: "#1D5F8C" },
};
let metricaMensal = "kg_redistribuidos";
let dadosMensais = [];
const MESES = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"];
function nomeMes(data, comAno) {
  const [ano, mes] = String(data).slice(0, 7).split("-");
  return MESES[Number(mes) - 1] + (comAno ? "/" + ano : "");
}
function trocarMetrica(m) {
  metricaMensal = m;
  document.querySelectorAll("#metricas button").forEach(b => b.classList.toggle("on", b.dataset.m === m));
  desenharMensal();
}
function desenharMensal() {
  const m = METRICAS[metricaMensal], vals = dadosMensais.map(d => Number(d[metricaMensal]));
  const W = 760, H = 300, esq = 56, base = H - 40, topo = 28;
  const teto = Math.max(...vals) * 1.15 || 1, passo = (W - esq - 16) / vals.length, larg = Math.min(96, passo * 0.56);
  const y = v => base - v * (base - topo) / teto;
  const linhas = [0, 0.25, 0.5, 0.75, 1].map(f => { const v = teto / 1.15 * f;
    return `<line x1="${esq}" x2="${W - 8}" y1="${y(v)}" y2="${y(v)}" stroke="#E3E9E0"/>
      <text x="${esq - 8}" y="${y(v) + 4}" text-anchor="end" font-size="12" fill="#5E6B60">${num(Math.round(v))}</text>`; }).join("");
  const barras = vals.map((v, k) => { const x = esq + passo * k + (passo - larg) / 2, ultimo = k === vals.length - 1;
    return `<rect x="${x}" y="${y(v)}" width="${larg}" height="${base - y(v)}" rx="6" fill="${m.cor}" opacity="${ultimo ? 0.55 : 1}"><title>${nomeMes(dadosMensais[k].mes, true)}: ${num(v)}${m.unidade}</title></rect>
      <text x="${x + larg / 2}" y="${y(v) - 8}" text-anchor="middle" font-size="14" font-weight="700" fill="#18241B">${num(v)}${m.unidade}</text>
      <text x="${x + larg / 2}" y="${base + 22}" text-anchor="middle" font-size="13" fill="#5E6B60">${nomeMes(dadosMensais[k].mes, true)}</text>`; }).join("");
  document.getElementById("grafico-mensal").innerHTML =
    `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${m.rotulo} por mês" style="width:100%;height:auto;font-family:inherit">${linhas}${barras}</svg>`;
}
