# Log de decisões

Cada etapa do projeto começa com alternativas na mesa. A decisão escolhida fica registrada aqui, com o motivo e o que foi descartado, para que qualquer pessoa entenda por que o projeto é do jeito que é.

| # | Data | Decisão | Status |
|---|---|---|---|
| D1 | 2026-11-03 | Fontes de dados: StatsBomb Open Data 2015/16 + Transfermarkt Datasets | Decidida |
| D2 | 2026-11-03 | Clube foco: Chelsea 2015/16 | Decidida |
| D3 | 2026-11-03 | Pasta e repositório do projeto | Decidida |

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
