# Log de decisões

Cada etapa do projeto começa com alternativas na mesa. A decisão escolhida fica registrada aqui, com o motivo e o que foi descartado, para que qualquer pessoa entenda por que o projeto é do jeito que é.

| # | Data | Decisão | Status |
|---|---|---|---|
| D1 | 2026-11-03 | Fontes de dados: StatsBomb Open Data 2015/16 + Transfermarkt Datasets | Decidida |
| D2 | 2026-11-03 | Clube foco: Chelsea 2015/16 | Decidida |
| D3 | 2026-11-03 | Pasta e repositório do projeto | Decidida (pasta `dados/` substituída pela D4) |
| D4 | 2026-11-03 | Dados brutos fora do OneDrive, em `C:\dados\chelsea_scouting` | Decidida |
| D5 | 2026-11-03 | Escopo: zagueiro, volante e lateral; depois, visão por setor do time | Decidida |
| D6 | 2026-11-04 | Modelo estrela: fato jogador × partida × posição, 4 fatos, KPIs finais, ligação StatsBomb × Transfermarkt e recorte de mercado | Decidida |
| D7 | 2026-11-04 | Carga: JSONs do StatsBomb por `OPENJSON` no SQL Server, staging com colunas achatadas, Transfermarkt descompactado e carregado por `BULK INSERT` | Decidida |
| D8 | 2026-11-08 | Cartões na staging de eventos: coluna `card` juntando `foul_committed.card` e `bad_behaviour.card`, para cortar os minutos dos expulsos | Decidida |

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

---

## D6 — Desenho do modelo estrela

**Decisão:** o pacote recomendado, em 6 partes.

**O que a conferência dos arquivos mostrou antes de desenhar** (2026-11-04):
- As escalações do StatsBomb **não têm data de nascimento**, só nome, apelido (`player_nickname`), país e camisa. A ligação com o Transfermarkt não pode depender da data de nascimento.
- O contrato do Transfermarkt (`players.contract_expiration_date`) é **só o atual** (2026). Não existe o histórico de quando terminava cada contrato em 2016.
- O mesmo jogador aparece com **dois nomes** no StatsBomb: o Kanté está como `N'Golo Kanté` (96 min) e `N''Golo Kanté` (3.084 min) no `jogadores.csv` do levantamento, que agrupou por nome. No modelo, a chave do jogador é o `player_id`.

### D6.1 — Grão da fato de desempenho: jogador × partida × posição jogada

Cada lance conta para a posição em que o jogador estava naquele momento (pelas escalações, `positions.from`/`to`). Isso permite separar quem jogou em mais de uma posição (o Azpilicueta jogou dos dois lados) e filtrar por data, adversário e técnico (Mourinho × Hiddink). Fica em torno de 50 mil linhas para as 4 ligas.

Os eventos lance a lance ficam só na **staging** do SQL Server: é lá que os indicadores são calculados antes de virarem a fato.

**Descartadas:**
- *Jogador × partida*: mistura posições dentro do mesmo jogo.
- *Jogador × temporada* (~2,5 mil linhas): perde datas, adversários e a troca de técnico.
- *Evento* (~5 milhões de linhas): permitiria mapas de passe, mas pesa demais para o objetivo.

### D6.2 — Fatos e dimensões: 4 fatos e 6 dimensões compartilhadas

| Tabela | Grão | Conteúdo | Fonte | Pergunta |
|---|---|---|---|---|
| `fato_desempenho` | jogador × partida × posição | Minutos + contagens dos indicadores | StatsBomb 2015/16 | Diagnóstico e Mercado |
| `fato_valor_mercado` | jogador × data da avaliação | Valor de mercado (2014 a 2026) | TM `player_valuations` | Mercado (orçamento) e Validação |
| `fato_atuacao` | jogador × partida TM | Minutos, gols, assistências, cartões (2014/15 a 2025/26) | TM `appearances` | Visão por setor (14/15 × 15/16) e Validação |
| `fato_transferencia` | jogador × transferência | Clube de origem e destino, taxa, data | TM `transfers` | Validação |

Dimensões: `dim_jogador`, `dim_posicao`, `dim_time`, `dim_partida`, `dim_liga`, `dim_data`.

A fato guarda **contagens com numerador e denominador** (passes e passes certos, duelos aéreos ganhos e perdidos). O "por 90" e os percentuais saem de medidas DAX, então somam certo em qualquer filtro.

**Descartada:** *2 fatos, com o mercado como atributos fixos do jogador* (valor em jun/2016, clube em 2018...): mais simples, mas perde a curva de valor e a evolução de minutos até 2026, que respondem à pergunta de Validação.

### D6.3 — Posição e setor

A `dim_posicao` tem a hierarquia **posição StatsBomb (25) → grupo → setor**:

| Grupo | Posições StatsBomb | Setor |
|---|---|---|
| Zagueiro | Center Back, Left Center Back, Right Center Back | Defesa |
| Lateral | Left Back, Right Back, Left Wing Back, Right Wing Back | Defesa |
| Volante | Left / Center / Right Defensive Midfield | Meio |
| Meia central | Left / Center / Right Center Midfield | Meio |
| Demais grupos (meia ofensivo, ponta, atacante, goleiro) | Restante | Meio / Ataque / Goleiro |

- **Volante só com as posições Defensive Midfield.** O Kanté (LDM), o Matić (LDM), o Mikel e o Fàbregas (RDM) já ficam nesse grupo. O Drinkwater (LCM) fica em "Meia central", que continua no modelo para a visão por setor.
- **Mínimo de 900 minutos no grupo de posição** (10 jogos) para entrar na comparação.

**Descartadas:** *Volante = DM + CM* (como no levantamento): mistura funções diferentes nos times de 4-3-3. *Mínimo de 600 min*: mais candidatos, mais ruído. *Mínimo de 1.350 min*: corta reservas que jogaram bem.

### D6.4 — Ligação StatsBomb × Transfermarkt

| Item | Como |
|---|---|
| Times (~78) | Tabela manual em CSV, versionada no repositório |
| Partidas | Data + mandante + visitante (pela tabela de times), conferindo pelo placar |
| Jogadores | Dentro da mesma partida e do mesmo time: a Pesquisa Difusa (Fuzzy Lookup) do SSIS compara o nome ou apelido do StatsBomb com o nome do TM entre os ~14 jogadores daquele time no jogo, e os minutos servem de conferência. Os casos que sobrarem vão para um CSV de exceções manuais |

Meta: **≥ 98% dos minutos** do StatsBomb casados com um jogador do Transfermarkt.

**Descartadas:**
- *Pesquisa Difusa global por nome + clube + nacionalidade*: mais risco de homônimos e de nomes completos ("Willian Borges da Silva").
- *Casar à mão só o Chelsea e os candidatos*: rápido, mas a busca de mercado precisa do valor de todos os jogadores.

### D6.5 — Indicadores finais (por 90 minutos)

| Posição | Indicadores |
|---|---|
| Zagueiro | Passes progressivos, conduções progressivas, acerto de passe %, desarmes + interceptações\*, recuperações\*, duelos aéreos ganhos %, erros que viraram chute (só contexto, fora do ranking) |
| Volante | Recuperações\*, desarmes + interceptações\*, pressões\*, passes progressivos, perdas de bola (quanto menos, melhor), acerto de passe % (novo em relação à D5) |
| Lateral | Passes-chave, passes na área, conduções progressivas, dribles certos, desarmes + interceptações\* |

\* **Ajustado por posse (PAdj):** quem tem mais a bola defende menos. O ajuste é `valor × 0,5 / (1 − posse do time na partida)`, calculado no ETL partida a partida (posse = participação do time no total de passes, como no levantamento). Importa aqui porque o 20º lugar do Chelsea em interceptações pode ser em parte efeito da posse.

**Passe progressivo:** mantida a regra do levantamento (passe certo, fora de bola parada, que termina no campo de ataque, x ≥ 60, pelo menos 25% mais perto do centro do gol do que começou). Os achados da D5 saíram dela. Com os eventos no SQL, a regra do Wyscout entra como teste de sensibilidade.

**Descartadas:**
- *Sem ajuste por posse*: confunde estilo de jogo com qualidade defensiva.
- *Passe progressivo pela regra do Wyscout* (avanço de 30 m no próprio campo, 15 m cruzando o meio, 10 m no campo de ataque): fica só como teste de sensibilidade.
- *Passe progressivo pela regra do FBref/Opta* (≥ 10 jardas, excluindo os 40% defensivos do campo): penaliza justamente o zagueiro, que é o foco.

### D6.6 — Recorte de mercado

| Item | Regra |
|---|---|
| Valor | Última avaliação do Transfermarkt até 30/06/2016 (medida DAX sobre a `fato_valor_mercado`) |
| Idade | Em 01/07/2016, pela `date_of_birth` do Transfermarkt |
| Contrato | **Fora**, e registrado como limitação: o dataset só tem o contrato atual |
| Orçamento | Parâmetros no Power BI (teto de valor e idade máxima), em vez de um valor fixo |
| Universo de candidatos | Jogadores das 4 ligas com ≥ 900 min no grupo de posição |

Referência para o teto de valor: as taxas reais da janela de 2016 no Transfermarkt são Kanté €35,8 mi, Batshuayi €39 mi e Marcos Alonso €23 mi. O David Luiz não apareceu na busca em `transfers` e vai ser conferido na etapa da ligação.

**Descartada:** *estimar o contrato pelo tempo desde a última transferência*: aproximação fraca, que poderia levar a conclusões erradas.

---

## D7 — Como os dados brutos entram no SQL Server

**Decisão:** o pacote recomendado, em 3 partes.

### D7.1 — JSONs do StatsBomb: `OPENJSON` no SQL Server

O SQL Server lê cada arquivo com `OPENROWSET(BULK ..., SINGLE_BLOB)`, converte de UTF-8 e grava nas tabelas de staging com `OPENJSON ... WITH`. A lista de partidas sai do próprio `matches\<liga>_27.json`, sem precisar listar a pasta. No caminho do SSIS, um Foreach Loop chama o mesmo SQL partida a partida. Assim **uma única lógica de leitura** atende ao DW feito em SQL e ao SSIS.

**Teste feito antes de decidir** (2026-11-04, SQL Server 2025 Developer 17.0, só leitura, sem alterar bancos): uma partida do Chelsea (`3753973`) deu 3.478 eventos e 963 passes, lidos em 47 a 87 ms. Para as 1.517 partidas, a leitura fica na casa de poucos minutos.

**Duas pegadinhas resolvidas no teste:**
- **Permissão:** o serviço `NT Service\MSSQLSERVER` não lia a pasta `statsbomb\` ("não existe ou você não tem direitos de acesso"). Com a autorização do usuário, recebeu **só leitura** em `C:\dados\chelsea_scouting` (comando em [`dados.md`](dados.md), com o jeito de desfazer).
- **Acentos:** `CAST(BulkColumn AS varchar(max)) COLLATE Latin1_General_100_CI_AS_SC_UTF8` estraga os acentos ("FÃ bregas"), porque a conversão passa pela collation do servidor (`Latin1_General_CI_AS`). O certo é gravar o `BulkColumn` direto numa coluna `varchar(max)` com collation UTF-8 ("Fàbregas" certo).

**Descartadas:**
- *Script Component em C# no SSIS*: C# escondido no pacote, difícil de ler e depurar. O caminho do DW SQL precisaria de outro leitor, então a lógica ficaria duplicada.
- *Converter para CSV antes* (PowerShell + C#): a extração ficaria num script fora do stack de BI, com mais ~1 a 2 GB em disco e as pegadinhas de aspas e acentos em CSV.

### D7.2 — Staging de eventos: colunas achatadas

Uma linha por evento (~5 milhões), só com as ~25 colunas que os indicadores da D6.5 usam: partida, período, minuto, time, jogador, posição, tipo, x/y de início e de fim, resultado e tipo do passe, assistência para chute, tipo e resultado do duelo, duelo aéreo ganho, falha na recuperação, xG e tipo do chute, sob pressão.

**Descartada:** *colunas achatadas + o JSON bruto de cada evento*: mais flexível para criar indicadores depois, mas ocupa ~4,6 GB a mais no banco. Se faltar algum campo, basta reler os arquivos, que continuam em `C:\dados`.

### D7.3 — Transfermarkt: descompactar e usar `BULK INSERT`

O SQL Server não lê `.gz` direto. Um passo novo no `baixar_dados.ps1` descompacta as tabelas para `transfermarkt\csv\`, e a carga usa `BULK INSERT ... FORMAT = 'CSV'`, que trata as aspas. No SSIS as tabelas entram pela Flat File Source, como no Olist.

**Descartada:** *descompactar dentro do SSIS* (Script Task): adiciona C# no pacote sem ganho.

---

## D8 — Cartões na staging de eventos

**Contexto:** a carga das escalações (Aula 7) mostrou que o lineup quase nunca encerra o trecho do jogador expulso: no Chelsea x Swansea (`3754078`), o Courtois é expulso aos 51:37 e segue no lineup como "Center Attacking Midfield" até o apito. Nos 1.517 arquivos de eventos há **413 expulsões** (196 vermelhos diretos + 217 segundos amarelos), mas só 30 trechos do lineup terminam por expulsão. A `stg.sb_events` da D7.2 não tinha coluna de cartão.

**Decisão:** uma coluna `card` (`NVARCHAR(50)`) = `COALESCE(foul_committed.card.name, bad_behaviour.card.name)`. O cartão vem de dois tipos de lance: falta (`Foul Committed`) e cartão sem falta, como reclamação ou simulação (`Bad Behaviour`). O `type_name` diz de qual veio, então juntar não perde informação. É o mesmo jeito do `aerial_won`, que já junta 4 campos. A `stg.sb_events` passa a ter 39 colunas, e o `fato_atuacao` corta os minutos do expulso no minuto do `Red Card` ou do `Second Yellow`.

**Teste feito antes da aula** (2026-11-08, tabela temporária, 38 partidas do Chelsea): 136.207 eventos em 5,8 s; 59 gols pró (55 chutes + 4 gols contra) e 53 contra (51 + 2); xG 53,58 (1,41/jogo) e xG contra 47,97 (1,26/jogo), iguais ao levantamento; Chelsea com 3 vermelhos, 2 segundos amarelos e 60 amarelos (15 deles por `Bad Behaviour`).

**Descartadas:**
- *Duas colunas* (`foul_committed_card` e `bad_behaviour_card`): mais fiel ao caminho do JSON, mas o fato teria que juntar as duas depois, sem ganho de informação.
- *Deixar sem cartão*: os minutos sairiam só do lineup e os expulsos ganhariam tempo a mais, o que distorce os indicadores por 90 minutos.
