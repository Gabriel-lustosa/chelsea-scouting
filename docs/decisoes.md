# Log de decisões

Cada etapa do projeto começa com alternativas na mesa. A decisão escolhida fica registrada aqui, com o motivo e o que foi descartado, para que qualquer pessoa entenda por que o projeto é do jeito que é.

| # | Data | Decisão | Status |
|---|---|---|---|
| D1 | 2026-11-03 | Fontes de dados: StatsBomb Open Data 2015/16 + Transfermarkt Datasets | Decidida |
| D2 | 2026-11-03 | Clube foco: Chelsea 2015/16 | Decidida |
| D3 | 2026-11-03 | Pasta e repositório do projeto | Decidida (pasta `dados/` substituída pela D4) |
| D4 | 2026-11-03 | Dados brutos fora do OneDrive, em `C:\dados\chelsea_scouting` | Decidida |
| D5 | 2026-11-03 | Escopo: zagueiro, volante e lateral; depois, visão por setor do time | Decidida |

---

## D1 — Fontes de dados

**Decisão:** usar duas fontes que se complementam.

| Fonte | Papel no projeto | Cobertura usada | Formato | Licença |
|---|---|---|---|---|
| [StatsBomb Open Data](https://github.com/statsbomb/open-data) | **Desempenho**: eventos lance a lance (passes, conduções, pressões, desarmes, chutes com xG) | Temporada 2015/16 (`season_id = 27`) | JSON | Gratuita, citando a StatsBomb como fonte |
| [Transfermarkt Datasets](https://github.com/dcaribou/transfermarkt-datasets) (dcaribou) | **Mercado**: valor de mercado, idade, contrato, transferências, atuações | 2015/16 para o cenário; até 2026 para validar o que aconteceu depois | CSV / DuckDB | CC0 |

**Cobertura conferida no StatsBomb 2015/16** (contagem de partidas em `matches/<competição>/27.json`, em 2026-11-03):

| Liga | `competition_id` | Partidas | Uso |
|---|---|---|---|
| Premier League | 2 | 380 / 380 | Clube foco + candidatos |
| La Liga | 11 | 380 / 380 | Candidatos |
| Serie A | 12 | 380 / 380 | Candidatos |
| Ligue 1 | 7 | 377 / 380 | Candidatos |
| Bundesliga | 9 | 34 (só jogos do Leverkusen) | Fora: não permite comparar com a liga |

**Por que essa combinação:**
- Desde 20/01/2026 o FBref não tem mais as estatísticas avançadas da Opta, e nenhuma fonte gratuita atual tem dados de eventos completos.
- O StatsBomb 2015/16 é a única base gratuita com **todas** as partidas de 4 grandes ligas lance a lance, o que permite medir cada posição pelo que ela faz em campo.
- O Transfermarkt traz a parte de mercado (preço, idade, contrato) e o que aconteceu com cada jogador depois de 2016. Com isso dá para **validar as recomendações com a história real**.

**Descartadas:**
- *Brasileirão*: não existe no StatsBomb, e o Transfermarkt só tem as temporadas 2024 e 2025 (parcial).
- *Understat* (xG atual): exige scraping e cobre mal os defensores. Fica como possível fase 2.
- *Sofascore / WhoScored / FotMob*: só por scraping, com termos de uso restritivos.
- *Pagas* (Wyscout, StatsBomb IQ, Opta): custo de clube profissional.

**Consequência a resolver:** as duas fontes não têm um ID de jogador em comum. Vai ser preciso uma tabela de correspondência (nome, data de nascimento, clube).

---

## D2 — Clube foco

**Decisão:** **Chelsea, temporada 2015/16.**

**Contexto real:** atual campeão, o Chelsea terminou em 10º lugar. Mourinho foi demitido em dezembro de 2015, e vários titulares renderam bem abaixo do esperado. Na janela de 2016, com o Conte, chegaram Kanté, David Luiz, Marcos Alonso e Batshuayi, e o time foi campeão em 2016/17.

**Por que o Chelsea:** é o cenário da pergunta original do projeto, *"o jogador não está rendendo na função, quem buscamos no mercado?"*. E a janela real de 2016 serve de gabarito para comparar com as recomendações do sistema.

**Descartados:**
- *Leicester* (repor o Kanté): ótima história, mas é cenário de saída de titular, não de baixo desempenho.
- *Napoli* (repor o Higuaín): o substituto real veio do Ajax, fora da base de dados.
- *Liverpool* (reconstrução com o Klopp): várias posições ao mesmo tempo, escopo maior.

**Restrição herdada da D1:** os candidatos precisam ter jogado a Premier League, La Liga, Serie A ou Ligue 1 em 2015/16 para terem dados de desempenho.

---

## D3 — Pasta e repositório

**Decisão:** `C:\Users\Lustosa\OneDrive\Desktop\PORTFÓLIO\projeto_chelsea_scouting`, ao lado do projeto Olist e no mesmo padrão dele (`01_sql/`, `02_ssis/`, `03_ssas/`, `04_powerbi/`, `dados/` fora do Git, README em português).

> Atualização: a pasta `dados/` dentro do projeto foi substituída pela D4.

---

## D4 — Onde ficam os dados brutos

**Decisão:** guardar os dados brutos em `C:\dados\chelsea_scouting`, fora do OneDrive e fora do Git, com uma subpasta por fonte (`statsbomb\`, `transfermarkt\`).

**Por que:**
- Volume: cada partida do StatsBomb tem cerca de 3 MB de eventos. Só a Premier League dá ~1,2 GB e as 4 ligas ~4,6 GB. Dentro do OneDrive tudo isso seria sincronizado com a nuvem, e o plano gratuito tem 5 GB.
- Caminho sem acento: evita as pegadinhas de "PORTFÓLIO" no SQL Server (`BULK INSERT`, `OPENROWSET`) e nos gerenciadores de conexão do SSIS.
- Os dados são públicos e dá para baixar de novo a qualquer momento. As instruções vão para o README (*Como rodar*).

**Descartadas:**
- *Pasta `dados/` dentro do projeto* (como previa a D3): sincronizaria até ~4,6 GB no OneDrive.
- *Manter no OneDrive com mais espaço*: o plano atual não comporta o volume.

---

## D5 — Escopo: posições e indicadores

**Decisão:** analisar **3 posições: zagueiro, volante e lateral** (os dois lados). Para cada uma, o diagnóstico mede os jogadores do Chelsea contra a mesma posição na liga, e o mercado busca candidatos nas 4 grandes ligas. Depois dessas 3 posições entra uma **visão por setor do time inteiro** (defesa, meio e ataque), para mostrar como a queda de produção se espalhou pelo elenco.

**De onde saiu a escolha:** do levantamento feito antes de decidir (scripts em `00_dados/levantamento/`, definições em [`dados.md`](dados.md)), com as 380 partidas da Premier League 2015/16 e o Transfermarkt para 2014/15:

| Achado | Números |
|---|---|
| A queda foi maior atrás | Gols sofridos subiram de 32 para 53; gols pró caíram de 73 para 59 (Transfermarkt) |
| Não foi só azar | xG de 1,41 por jogo (8º) e xG contra de 1,26 (9º): números de meio de tabela. Média dos 4 primeiros: 1,70 e 1,02 |
| **Zagueiros** não constroem | Setor de defesa em 17º em passes progressivos, 17º em conduções e 19º em recuperações. Terry, Cahill e Zouma entre os percentis 0 e 5 de passes progressivos entre os zagueiros da liga. Time em 20º de 20 em interceptações |
| **Meio** recupera pouco | Setor de meio em 17º em recuperações, 14º em pressões e 16º em duelos aéreos, mesmo com passe de elite (Fàbregas nos percentis 97 a 100) |
| **Laterais** criam pouco | Baba nos percentis 7 a 19 em criação; Ivanović no percentil 15 em passes-chave e no 20 em conduções |
| Ataque cria muito, mas finaliza mal | 1º em passes na área, conduções e dribles; Hazard caiu de 14 para 4 gols e ficou no percentil 17 de xG |

As 3 posições coincidem com a janela real de 2016 (David Luiz, Kanté e Marcos Alonso), o que dá um gabarito para a pergunta de Validação. A escolha saiu dos números do levantamento, não da janela real.

**Indicadores iniciais** (por 90 minutos; a lista final é fechada no desenho do modelo):

| Posição | Indicadores |
|---|---|
| Zagueiro | Passes progressivos, conduções progressivas, acerto de passe, desarmes + interceptações, recuperações, duelos aéreos ganhos %, erros que viraram chute |
| Volante | Recuperações, desarmes + interceptações, pressões, passes progressivos, perdas de bola |
| Lateral | Passes-chave, passes na área, conduções progressivas, dribles certos, desarmes + interceptações |

**Visão por setor (depois das 3 posições):** como o StatsBomb não tem a Premier League 2014/15, a queda por setor vai ser medida (a) contra a liga e os 4 primeiros em 2015/16, com os indicadores de evento, e (b) de 2014/15 para 2015/16, com gols, assistências, minutos e gols sofridos do Transfermarkt. O formato exato fica para quando a etapa chegar.

**Descartadas:**
- *3 posições + atacante/ponta*: a queda do ataque parece individual (Hazard voltou a fazer 16 gols em 2016/17), não falta de jogador no elenco. Aumentaria o trabalho em cerca de 30%.
- *Só um setor (defesa inteira)*: deixaria de fora o meio, um dos achados mais fortes.
- *Elenco todo por posição*: indicadores genéricos e diagnóstico sem foco. A visão do time inteiro entra por setor, não posição a posição.

**Fora do escopo:** goleiro. Os gols sofridos ficaram 3 acima do xG contra, mas o StatsBomb aberto não tem o xG depois do chute, que é o que mede melhor o goleiro.
