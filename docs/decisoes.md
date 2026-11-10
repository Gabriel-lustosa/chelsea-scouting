# Log de decisões

Cada etapa do projeto começa com alternativas na mesa. A decisão escolhida fica registrada aqui, com o motivo e o que foi descartado, para que qualquer pessoa entenda por que o projeto é do jeito que é.

| # | Data | Decisão | Status |
|---|---|---|---|
| D1 | 2026-11-03 | Fontes de dados: StatsBomb Open Data 2015/16 + Transfermarkt Datasets | Decidida |
| D2 | 2026-11-03 | Clube foco: Chelsea 2015/16 | Decidida |
| D3 | 2026-11-03 | Pasta e repositório do projeto | Decidida (pasta `dados/` substituída pela D4) |
| D4 | 2026-11-03 | Dados brutos fora do OneDrive, em `C:\dados\chelsea_scouting` | Decidida |
| D5 | 2026-11-03 | Escopo: zagueiro, volante e lateral; depois, visão por setor do time | Decidida |
| D6 | 2026-11-04 | Modelo estrela: fato jogador × partida × posição, 4 fatos, KPIs finais, ligação StatsBomb × Transfermarkt e recorte de mercado | Decidida (ligação da D6.4 revista na D10.1 e, nos times, na D14.1) |
| D7 | 2026-11-04 | Carga: JSONs do StatsBomb por `OPENJSON` no SQL Server, staging com colunas achatadas, Transfermarkt descompactado e carregado por `BULK INSERT` | Decidida |
| D8 | 2026-11-08 | Cartões na staging de eventos: coluna `card` juntando `foul_committed.card` e `bad_behaviour.card`, para cortar os minutos dos expulsos | Decidida |
| D9 | 2026-11-08 | xG na staging como `DECIMAL(11,10)`, lido como `FLOAT` no `OPENJSON` (há valores em notação científica e com até 10 casas) | Decidida |
| D10 | 2026-11-09 | DW no SQL Server: ligação de jogadores em SQL por time × temporada, construção em dois blocos (StatsBomb, depois Transfermarkt), Transfermarkt só dos jogadores ligados, tabelas no `dw` por scripts com chave substituta | Decidida (exceções da D10.1 em lista `VALUES`, D18.2) |
| D11 | 2026-11-09 | Padrões do DW: estrutura e carga em scripts separados, sem FK declarada (conferência de órfãos), `dim_data` com chave AAAAMMDD de 2014 a 2026 e colunas de temporada e do cenário | Decidida |
| D12 | 2026-11-09 | `dim_liga`: as 65 competições do Transfermarkt mais as 4 que faltam no CSV, com nome por regra (e exceções) e tipo em português | Decidida |
| D13 | 2026-11-09 | `dim_posicao`: 9 grupos com os setores do levantamento (meia aberto no Meio, ponta e atacante no Ataque), nomes em português, lado, escopo e ordem de exibição | Decidida |
| D14 | 2026-11-09 | `dim_time`: times ligados ao Transfermarkt pelas partidas (votação por data, liga e placar, 80/80), os 80 do StatsBomb agora e os clubes do TM no Bloco 2, com nome curto, posição final em 2015/16 e marcação dos times do estudo | Decidida |
| D15 | 2026-11-09 | `dim_partida` no grão partida × time (2 linhas por partida), as 1.517 do StatsBomb agora e os jogos do TM no Bloco 2, com técnico e formação do Transfermarkt | Decidida |
| D16 | 2026-11-09 | `dim_jogador`: nome de exibição (apelido ou nome, apóstrofo corrigido) e nome completo, país, time do fim de 2015/16 e marcações de troca de time e do elenco do Chelsea; posição principal depois da fato; colunas do TM criadas agora e preenchidas no Bloco 2 | Decidida |
| D17 | 2026-11-10 | `fato_desempenho`: minutos por tempo com os acréscimos e o corte dos expulsos, lance ligado pela posição do evento, tabela de trechos na staging, colunas com PAdj no ETL e posse na `dim_partida`, grupo principal antes da posição | Decidida |
| D18 | 2026-11-10 | Ligação dos jogadores: regras da D10.1 + regra de palavras e troca do `Đ` (99,30% dos minutos), 18 exceções numa lista `VALUES` no script, aspas duplas corrigidas na `dim_jogador`, tabela de ligação na staging | Decidida |
| D19 | 2026-11-10 | Resto do Bloco 2: atributos do TM e 5 jogadores do Chelsea 2014/15 na `dim_jogador`, 963 clubes das fatos na `dim_time`, só o lado do clube do jogador na `dim_partida`, fatos a partir de 2014 | Decidida |

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
| Demais grupos (goleiro, meia aberto, meia ofensivo, ponta, atacante: fechados na D13) | Restante | Goleiro / Meio / Ataque |

- **Volante só com as posições Defensive Midfield.** O Kanté (LDM), o Matić (LDM), o Mikel e o Fàbregas (RDM) já ficam nesse grupo. O Drinkwater (LCM) fica em "Meia central", que continua no modelo para a visão por setor.
- **Mínimo de 900 minutos no grupo de posição** (10 jogos) para entrar na comparação.

**Descartadas:** *Volante = DM + CM* (como no levantamento): mistura funções diferentes nos times de 4-3-3. *Mínimo de 600 min*: mais candidatos, mais ruído. *Mínimo de 1.350 min*: corta reservas que jogaram bem.

### D6.4 — Ligação StatsBomb × Transfermarkt

| Item | Como |
|---|---|
| Times (~78) | Tabela manual em CSV, versionada no repositório (revisto na D14.1: ligação pelas partidas, sem CSV) |
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

---

## D9 — Tipo do xG na staging de eventos

**Contexto:** a primeira carga da `stg.sb_events` (Aula 8, 2026-11-08) parou no arquivo `3754162.json` com o erro 8114 ("Erro ao converter tipo de dados nvarchar em decimal"). Em 7 chutes o xG vem em notação científica (`"statsbomb_xg" : 1.8E-4`), que o `DECIMAL` não lê. A contagem nos 1.517 arquivos mostrou outro problema: dos 37.888 xG, 17.725 têm 9 casas e 997 têm 10, então a coluna `DECIMAL(9,8)` da D7.2 já arredondava 18.722 valores. Não cumpria a "soma exata" que justificou o `DECIMAL`.

**Decisão:** coluna `shot_statsbomb_xg DECIMAL(11,10)`. No `OPENJSON ... WITH` o xG é lido como `FLOAT`, que entende o `E-4`, e convertido no `SELECT` com `CAST(... AS DECIMAL(11,10))`. **Teste nos 1.517 arquivos:** 0 diferenças entre esse caminho e o número escrito no JSON, e os 7 `1.8E-4` viram `0.0001800000`.

**Descartadas:**
- *Manter `DECIMAL(9,8)` e só ler como `FLOAT`*: destrava a carga, mas continua arredondando a 9ª e a 10ª casa.
- *Coluna `FLOAT`*: mais simples, mas a soma deixa de ser exata.

---

## D10 — Como montar o DW no SQL Server

**Contexto:** com a staging carregada (Aula 9, 2026-11-09), falta transformar as 10 tabelas no modelo estrela da D6. Antes de decidir, foi testada a ligação de jogadores no elenco do Chelsea: comparando nome e apelido sem acento entre o StatsBomb e o Transfermarkt, dentro do time na temporada, **27 dos 28 jogadores casaram sozinhos**. Só o Mikel ficou de fora (`John Obi Mikel` no StatsBomb, outro nome no Transfermarkt). O SQL Server 2025 tem funções de semelhança de texto (`JARO_WINKLER_SIMILARITY`, `EDIT_DISTANCE_SIMILARITY`), mas elas só funcionam com o recurso em prévia (`PREVIEW_FEATURES`) ligado no banco, e ele está desligado.

**Decisão:** o pacote recomendado, em 4 partes.

### D10.1 — Ligação dos jogadores: em SQL, por regras em ordem, dentro do time × temporada

| Ordem | Regra (sem acento, `COLLATE ..._CI_AI`) |
|---|---|
| 1 | Nome do Transfermarkt = apelido do StatsBomb (ou o nome, quando não há apelido) |
| 2 | Nome do Transfermarkt = nome completo do StatsBomb |
| 3 | Último sobrenome igual |
| 4 | O que sobrar vai para um CSV de exceções manuais, versionado no repositório |

Os minutos da temporada nas duas fontes servem de conferência. A meta da D6.4 continua: **≥ 98% dos minutos** do StatsBomb casados. No SSIS, a mesma ligação é refeita com a Pesquisa Difusa (Fuzzy Lookup) e o resultado é comparado com o do SQL (`EXCEPT` nos dois sentidos), como no Olist.

**O que muda na D6.4:** a ligação passa a ser feita no SQL (o DW em SQL continua sendo a referência dos números) e compara os jogadores dentro do **time na temporada**, não dentro de cada partida. Fica mais simples e não depende de ligar as partidas antes. Quem trocou de time em janeiro aparece nos dois elencos e é ligado nos dois.

**Descartadas:**
- *Somar a regra `JARO_WINKLER_SIMILARITY` antes do CSV de exceções*: menos casos à mão, mas exige ligar o recurso em prévia no banco.
- *Ligação só no SSIS, como na D6.4*: o DW em SQL deixaria de ser a referência e só ficaria completo depois do SSIS.

### D10.2 — Ordem: dois blocos, primeiro o StatsBomb

| Bloco | Tabelas | Pergunta respondida |
|---|---|---|
| 1. StatsBomb | `dim_data`, `dim_liga`, `dim_posicao`, `dim_time`, `dim_partida`, `dim_jogador` (atributos do StatsBomb) e `fato_desempenho` (trechos de posição, corte dos expulsos da D8, ajuste por posse e passe progressivo da D6.5) | Diagnóstico |
| 2. Transfermarkt | Ligação de times, partidas e jogadores; atributos do TM na `dim_jogador` e na `dim_partida`; `fato_valor_mercado`, `fato_atuacao`, `fato_transferencia` | Mercado e Validação |

A parte mais difícil em SQL (a `fato_desempenho`) não fica esperando a ligação, e a pergunta do Diagnóstico sai cedo.

**Descartadas:**
- *Todas as ligações e dimensões primeiro, depois as 4 fatos*: segue a ordem de dependência, mas a ligação trava tudo e o primeiro resultado demora.
- *Transfermarkt inteiro primeiro*: começa pelo mais fácil, mas adia o centro do projeto.

### D10.3 — Transfermarkt no DW: só os jogadores ligados

Entram os jogadores ligados aos 2.176 do StatsBomb 2015/16, mais o elenco do Chelsea em 2014/15 (para a visão por setor 14/15 × 15/16 da D5), com todas as atuações, avaliações e transferências deles de 2014 a 2026.

**Descartadas:**
- *Transfermarkt inteiro* (50 mil jogadores, 1,9 milhão de atuações): modelo pesado e quase todo sem uso.
- *Só zagueiros, volantes e laterais*: perde a visão por setor do time inteiro.

### D10.4 — Tabelas no schema `dw`, carregadas por scripts SQL

- Scripts numerados na sequência dos atuais (`04_...`, `05_...`), com `TRUNCATE` + `INSERT`, para poder rodar de novo.
- Cada dimensão com chave substituta (`INT IDENTITY`) e as chaves das fontes preservadas (`sb_player_id`, `tm_player_id` etc.), como no Olist.
- Passos intermediários em tabelas da `stg` (ex.: trechos de posição de cada jogador na partida).

**Descartadas:**
- *Views no `dw` em cima da staging*: a `fato_desempenho` recalcularia 5,3 milhões de eventos a cada leitura.
- *Stored procedures*: mais uma camada para aprender agora, sem ganho real no portfólio.

---

## D11 — Padrões do DW e a `dim_data`

**Contexto:** antes da primeira tabela do DW (Aula 10, 2026-11-09), faltava definir como os scripts se dividem, se há chave estrangeira e como é a dimensão de datas. Datas encontradas na staging: partidas do StatsBomb de 07/08/2015 a 17/05/2016; atuações do Transfermarkt de 03/07/2012 a 28/06/2026; avaliações desde 2014 (recorte da D10.3) até 12/06/2026; transferências de 01/07/1993 a 30/06/2030 (fim de empréstimo previsto).

**Decisão:** o pacote recomendado, em 4 partes.

### D11.1 — Estrutura e carga em scripts separados

`01_sql/04_dw_tabelas.sql` só cria as tabelas do schema `dw`; `01_sql/05_dw_carga.sql` só carrega (`TRUNCATE` + `INSERT`). Os dois crescem por aula, com checklist no cabeçalho, como os scripts da staging. A carga roda quantas vezes for preciso sem recriar nada, e o `04` também cria as tabelas no banco do SSIS (`chelsea_scouting_ssis`).

**Descartada:** *um script que apaga, cria e carrega cada tabela, como no Olist*: cada recarga recriaria as tabelas, e a estrutura teria que ser copiada para o SSIS.

### D11.2 — Sem chave estrangeira declarada

A integridade entre fato e dimensão é conferida no fim de cada carga de fato (linhas órfãs, esperado 0). O SQL Server não aceita `TRUNCATE` numa tabela referenciada por FK, e o SSAS e o Power BI definem os relacionamentos deles.

**Descartada:** *FKs declaradas, como no Olist*: o banco barraria o órfão sozinho, mas a carga teria que trocar o `TRUNCATE` por `DELETE` + `DBCC CHECKIDENT`, mais lenta na fato.

### D11.3 — `dim_data`: chave AAAAMMDD, de 01/01/2014 a 31/12/2026

Chave inteligente (`20160630`), exceção ao `IDENTITY` da D10.4, como no Olist: é legível, e a fato calcula a chave direto da data. São 4.748 dias, cobrindo as avaliações desde 2014, a temporada 2014/15 e o Transfermarkt até 2026. Datas fora do intervalo (transferências antes de 2014 ou previstas depois de 2026) já ficam fora pelo recorte da D10.3.

**Descartadas:** *1993 a 2030* (38 anos de calendário para usar 13); *chave `IDENTITY`* (toda fato teria que procurar a chave, sem ganho).

### D11.4 — Colunas da `dim_data`: as do Olist + temporada e cenário

As colunas do Olist (ano, trimestre, mês, nomes em português, dia, dia da semana, fim de semana) e mais três:

| Coluna | Regra | Exemplo |
|---|---|---|
| `temporada` | De 01/07 a 30/06 | `'2015/16'` |
| `temporada_ano_inicio` | Ano em que a temporada começa, igual à coluna `season` do Transfermarkt | `2015` |
| `periodo_cenario` | Corte da D6.6: até 30/06/2016 ou depois | `'Até a janela de 2016'` / `'Depois'` |

**Atenção:** a `temporada` da `dim_data` é a regra do calendário. A temporada **de uma partida** vem da própria partida (`dim_partida`), porque 221 jogos das 4 ligas na temporada 2019/20 foram disputados depois de 30/06/2020 (pandemia), e a regra de 1º de julho os colocaria em 2020/21.

**Descartadas:** *coluna de janela de transferências* (verão = jul/ago, inverno = jan): aproximação, porque as datas reais mudam por país e ano; *só as colunas do Olist, com a temporada no DAX*: a mesma regra se repetiria em várias medidas.

---

## D12 — `dim_liga`: quais competições e como exibir

**Contexto** (2026-11-09): o StatsBomb tem só as 4 ligas (`competition_id` 2, 11, 12 e 7). O Transfermarkt tem 65 competições no `competitions.csv` (31 ligas de 1ª divisão, copas, supercopas, competições europeias e de seleções), mas **4 competições aparecem nas atuações sem estar no CSV**: `CGB` (Copa da Liga Inglesa, 2.348 atuações), `POCP` (Taça da Liga de Portugal, 9.769), `KLUB` (Mundial de Clubes, 1.808) e `UKRS` (Supercopa da Ucrânia, 275). Os nomes vêm como no endereço da página (`uefa-champions-league`, `laliga`), e a classificação de tipo põe a Europa League como `other`.

### D12.1 — Todas as competições: 65 do Transfermarkt + 4 escritas no script (69)

As 4 ligas recebem também o código do StatsBomb. Toda atuação da `fato_atuacao` (D10.3) encontra a sua competição (conferido: 0 atuações sem competição). Ficam fora só os 200 jogos do campeonato colombiano (`COL1`) de 2025, que estão na `tm_games` sem nenhuma atuação.

**Descartadas:** *só as competições que aparecerem nas fatos* (a dimensão teria que ser refeita no Bloco 2); *as 4 ligas + "Outras"* (a Validação perderia Champions League e copas × liga).

### D12.2 — Nome por regra, com exceções, e tipo em português

| Coluna | Regra |
|---|---|
| `nome` | Troca `-` por espaço e põe maiúscula em cada palavra (`uefa-champions-league` → `UEFA Champions League`, com `UEFA` e `DFB` corrigidos). Exceções escritas à mão: as 4 ligas com o nome do StatsBomb (`Premier League`, `La Liga`, `Serie A`, `Ligue 1`), as 4 que faltam, `FA Cup`, `AFC Asian Cup`, `Africa Cup of Nations` e `Copa del Rey` |
| `tipo` | `Liga nacional`, `Copa nacional`, `Supercopa` (inclui a Supercopa da UEFA), `Competição europeia` (Champions, Europa e Conference League e as eliminatórias), `Seleções`, `Mundial de Clubes`, `Playoff` |
| `confederacao` | Em português: `Europa`, `Américas`, `Ásia`, `África`, `FIFA` |
| `eh_liga_do_estudo` | 1 nas 4 ligas do StatsBomb |

Colunas: `sk_liga` (`IDENTITY`, na ordem do código do Transfermarkt), `tm_competition_id`, `sb_competition_id` (NULL fora das 4 ligas), `nome`, `tipo`, `pais`, `confederacao`, `eh_liga_do_estudo`.

**Descartadas:** *CSV escrito à mão com as 69* (cada nome perfeito, mas é trabalho manual e mais uma carga; esse tipo de CSV só faz falta de verdade na ligação dos times); *nome e tipo como vêm do Transfermarkt* (`laliga` e a Europa League como `other` no dashboard).

---

## D13 — `dim_posicao`: grupos e colunas

**Contexto** (2026-11-09): as escalações do StatsBomb usam 24 das 25 posições da especificação (o `Secondary Striker`, id 25, não aparece). A D6.3 já tinha fixado Zagueiro, Lateral, Volante e Meia central. Faltava o grupo do goleiro, dos meias abertos (Right/Left Midfield), dos meias ofensivos, das pontas e dos atacantes. No levantamento (D5), o setor saiu do nome da posição: tudo com "Midfield" no Meio, Wing e Forward no Ataque.

### D13.1 — 9 grupos, com os setores do levantamento

| Grupo | Posições StatsBomb (id) | Setor |
|---|---|---|
| Goleiro | Goalkeeper (1) | Goleiro |
| Zagueiro | Right / Left Center Back, Center Back (3, 4, 5) | Defesa |
| Lateral | Right / Left Back, Right / Left Wing Back (2, 6, 7, 8) | Defesa |
| Volante | Right / Center / Left Defensive Midfield (9, 10, 11) | Meio |
| Meia central | Right / Center / Left Center Midfield (13, 14, 15) | Meio |
| Meia aberto | Right / Left Midfield (12, 16) | Meio |
| Meia ofensivo | Right / Center / Left Attacking Midfield (18, 19, 20) | Meio |
| Ponta | Right / Left Wing (17, 21) | Ataque |
| Atacante | Right / Left Center Forward, Center Forward, Secondary Striker (22, 23, 24, 25) | Ataque |

Os setores ficam iguais aos do levantamento, e os achados da D5 continuam comparáveis. O meia aberto do 4-4-2 fica separado do ponta do 4-3-3. Conferido: Goleiro 3.081 trechos, Defesa 16.627, Meio 21.645, Ataque 15.531 (total 56.884, a `stg.sb_lineups` inteira).

**Descartadas:** *Ponta = meia aberto + ponta, tudo no Ataque*: mudaria o setor de 4.502 trechos em relação ao levantamento, e o meia aberto do 4-4-2 recua para defender; *um grupo "Meia ofensivo/Ponta"*, como no levantamento: o grupo ficaria em dois setores e quebraria a hierarquia posição → grupo → setor.

### D13.2 — Colunas para o Power BI

| Coluna | Conteúdo |
|---|---|
| `sk_posicao` | `IDENTITY`, na ordem do id do StatsBomb (sai igual ao `sb_position_id`) |
| `sb_position_id`, `posicao` | Id e nome do StatsBomb (o nome confere com o das escalações) |
| `posicao_pt`, `sigla` | Nome em português (`Volante esquerdo`) e sigla (`LDM`) |
| `lado` | `Direito`, `Centro` ou `Esquerdo`, pelo começo do nome (`Right` / `Left`) |
| `grupo`, `setor` | Hierarquia da D13.1 |
| `eh_escopo` | 1 em Zagueiro, Lateral e Volante (D5): 10 posições |
| `ordem_grupo`, `ordem_setor` | Ordem de exibição (Goleiro, Defesa, Meio, Ataque), em vez da alfabética |

As 25 linhas ficam escritas no script com `VALUES` (a staging não tem tabela de posições), em duas listas: posição → grupo e grupo → setor, ordem e escopo. Assim cada grupo tem um setor só. O `Secondary Striker` entra mesmo sem uso, para a dimensão ficar completa.

**Descartada:** *só id, nome, grupo e setor*: gráficos em ordem alfabética, nomes em inglês e o filtro de escopo refeito em cada visual.

---

## D14 — `dim_time`: ligação dos times e colunas

**Contexto** (2026-11-09): o StatsBomb tem 80 times nas 4 ligas, cada um com um nome só. Os 80 clubes do Transfermarkt nessas ligas em 2015/16 estão todos na `tm_clubs`, mas só 24 dos 80 nomes batem com os do StatsBomb ("Chelsea" × "Chelsea FC", "Lazio" × "Società Sportiva Lazio S.p.A.", "Athletic Club" × "Athletic Bilbao"). As transferências, jogos e avaliações do TM citam 18.636 clubes, dos quais 17.840 não estão na `tm_clubs` (clubes pequenos, categorias de base).

### D14.1 — Ligação dos times pelas partidas, com votação

Cada partida do StatsBomb é cruzada com os jogos do Transfermarkt da mesma liga, na mesma data e com o mesmo placar. Em 297 partidas aparece mais de um jogo possível (mesmo dia, mesmo placar), então uma partida sozinha não decide: para cada time do StatsBomb, conta-se quantas vezes cada clube do TM apareceu no lugar dele, e o mais votado é o par. Testado: **80 de 80 times ligados**, cada um a um clube diferente, com pelo menos 37 votos para o vencedor e no máximo 5 para o segundo.

**O que muda na D6.4:** a tabela manual de times em CSV sai, e a ligação dos times passa do Bloco 2 para o Bloco 1 (D10.2). A ligação das partidas continua como na D6.4 (data + mandante + visitante, pela `dim_time`).

**Descartadas:** *CSV manual com os 80 pares* (D6.4): trabalho à mão, com 56 nomes diferentes; *regras de nome, como nos jogadores*: só 24 iguais, e "Athletic Club" × "Athletic Bilbao" não casa por regra simples.

### D14.2 — Agora os 80 do StatsBomb; no Bloco 2, os clubes do TM

Os 80 times entram já com `sb_team_id` e `tm_club_id`. No Bloco 2 entram os clubes do Transfermarkt que as fatos usarem, com `sb_team_id` NULL, quando o recorte dos jogadores da D10.3 já existir. Para os que não estão na `tm_clubs`, o nome vem das próprias tabelas (ex.: `from_club_name` das transferências).

**Descartadas:** *tudo agora* (80 + 796 da `tm_clubs` + clubes das transferências): sem o recorte dos jogadores, entrariam milhares de clubes sem uso, e o trabalho seria refeito no Bloco 2; *só os 80, para sempre*: o clube de origem e o de destino das transferências da Validação ficariam sem dimensão.

### D14.3 — Colunas

| Coluna | Conteúdo |
|---|---|
| `sk_time` | `IDENTITY`, na ordem do `sb_team_id` |
| `sb_team_id` | Chave do StatsBomb; NULL nos clubes que só existem no TM (Bloco 2). Única pelo índice filtrado `uq_dim_time_sb_team_id` (`WHERE sb_team_id IS NOT NULL`), porque uma `UNIQUE` comum aceita um NULL só |
| `tm_club_id` | Chave do Transfermarkt (`uq_dim_time_tm_club_id`) |
| `nome` | Curto, do StatsBomb ("Chelsea", "Lazio"); no Bloco 2, o do TM para quem não está no StatsBomb |
| `nome_tm` | Nome oficial do Transfermarkt |
| `pais` | País da liga (`dim_liga.pais`) |
| `liga_2015_16` | Nome da liga em 2015/16 (`dim_liga.nome`) |
| `posicao_2015_16` | Posição final, do TM: a da última partida do clube na temporada (`home_club_position` / `away_club_position`). Confere com a tabela real (Leicester 1º, Arsenal, Tottenham, Manchester City; Chelsea 10º). Pelos jogos do StatsBomb não dá: faltam 3 partidas da Ligue 1 |
| `eh_time_do_estudo` | 1 nos 80 times das 4 ligas |

A `posicao_2015_16` responde direto ao "contra os 4 primeiros" da visão por setor (D5).

**Descartada:** *só os dois IDs, nome e país*: a comparação com os 4 primeiros teria que ser montada no DAX.

---

## D15 — `dim_partida`: grão, recorte e colunas

**Contexto** (2026-11-09): com a `dim_time` pronta, a regra da D6.4 para as partidas (data + mandante + visitante) casou **1.517 de 1.517** partidas do StatsBomb com jogos diferentes do Transfermarkt, todas com o mesmo placar. O técnico vem preenchido em 3.034 de 3.034 lados de partida no TM e em 2.976 no StatsBomb (58 vazios, quase todos na Ligue 1; nomes completos e um com TAB no fim). Os 2.175 jogadores das 4 ligas jogaram cerca de 45 mil jogos TM de 2014 a 2026 (71 mil combinações jogo × time).

### D15.1 — Grão: partida × time

Duas linhas por partida, cada uma vista do lado de um time (mando, adversário, técnico, gols pró e contra, resultado). As fatos ligam pela partida + time do jogador: a `fato_desempenho` pelo `sb_match_id` + `sb_team_id`, a `fato_atuacao` pelo `tm_game_id` + `tm_club_id` (o TM traz o clube do jogador em cada jogo). Assim, Mourinho × Hiddink, casa × fora, resultado e "contra os 4 primeiros" viram filtros diretos. Contar partidas pede `DISTINCTCOUNT` (cada uma tem 2 linhas).

**Descartada:** *uma linha por partida, com mandante e visitante*: o técnico "do meu time" exigiria `eh_mandante` na fato e escolha no DAX, e o adversário uma 2ª relação inativa com a `dim_time` e `USERELATIONSHIP` em cada medida.

### D15.2 — Agora as 1.517 do StatsBomb; no Bloco 2, os jogos do TM

As 1.517 partidas (3.034 linhas) entram já com `tm_game_id` e `tm_club_id`. No Bloco 2 entram os jogos TM das atuações dos jogadores ligados, com `sb_match_id` e `sb_team_id` NULL (mesmo padrão da D14.2).

**Descartadas:** *os 88.958 jogos do TM agora* (cerca de 178 mil linhas, quase todas sem jogador ligado); *só as do StatsBomb*: o `fato_atuacao` ficaria sem partida, técnico e resultado.

### D15.3 — Colunas, com técnico e formação do Transfermarkt

| Grupo | Colunas |
|---|---|
| Chaves | `sk_partida` (`IDENTITY`, na ordem da data), `sb_match_id` + `sb_team_id` (únicas por índice filtrado, NULL no Bloco 2), `tm_game_id` + `tm_club_id` (`UNIQUE`) |
| Partida | `data`, `temporada` (do jogo, D11), `liga` (`dim_liga.nome`), `rodada`, `confronto` ("Chelsea 2 x 2 Swansea City", mandante primeiro) |
| Lado do time | `mando` (Casa / Fora), `adversario`, `posicao_adversario_2015_16`, `tecnico`, `tecnico_adversario`, `formacao`, `formacao_adversario`, `gols_pro`, `gols_contra`, `resultado` (Vitória / Empate / Derrota) |

O técnico e a formação vêm do Transfermarkt: completo nos 3.034 lados, nome curto e a mesma fonte dos jogos do Bloco 2. Os gols também vêm do TM (iguais ao StatsBomb nas 1.517).

**Descartadas:** *técnico do StatsBomb* (`COALESCE(apelido, nome)`): 58 lados vazios, um nome com TAB, e o Bloco 2 teria que usar o TM de qualquer jeito; *só chaves, data, mando, adversário e resultado*: sem técnico, e o corte Mourinho × Hiddink é central (D6.1). Estádio, árbitro, público e horário ficam fora (não respondem às 3 perguntas; podem entrar depois).

---

## D16 — `dim_jogador`: nome, atributos de 2015/16 e colunas que chegam depois

**Contexto** (2026-11-09): o StatsBomb tem 2.176 jogadores nas escalações. Só 9 aparecem com dois nomes no mesmo `player_id`: 8 pelo apóstrofo duplicado do JSON (`N''Golo` × `N'Golo`, `O''Shea`, `M''Vila`) e o Fernandinho ("Rosa" em 32 jogos, "Roza" em 1). 1.310 (60%) não têm apelido, e nesses o nome já é o usado no dia a dia ("Eden Hazard"); com apelido, o nome completo é longo ("Willian Borges da Silva"). 7 jogadores têm dois países e 1 não tem país. 103 trocaram de time durante a temporada (Cuadrado Chelsea → Juventus, Shelvey Swansea → Newcastle). 33.391 dos 56.884 trechos de posição não têm hora de fim, e o corte dos expulsos (D8) ainda não foi feito: os minutos certos só saem na `fato_desempenho`.

### D16.1 — Nome de exibição + nome completo

`nome` = apelido, ou o nome quando não há apelido, com `''` trocado por `'`; quando ainda sobra mais de uma versão, fica a de mais partidas. `nome_completo` também fica, para as regras 2 e 3 da ligação com o Transfermarkt (D10.1).

**Descartada:** *só o nome completo*: "Willian Borges da Silva" e "Francesc Fàbregas i Soler" nos gráficos.

### D16.2 — País, time do fim da temporada e marcações

| Coluna | Regra |
|---|---|
| `pais` | O mais frequente nas escalações |
| `time_fim_2015_16` | Time do último jogo da temporada: quem negociaria o jogador na janela. O time de cada partida continua na fato (`sk_time`) |
| `trocou_de_time_2015_16` | 1 nos 103 que jogaram por mais de um time |
| `eh_elenco_chelsea_2015_16` | 1 nos 28 que jogaram pelo Chelsea (inclui o Cuadrado, que terminou na Juventus) |

**Descartadas:** *time com mais jogos*: para quem trocou em janeiro, mostra o time antigo, que não negociaria mais o jogador; *sem time na dimensão*: sem filtro direto do elenco e lista de Mercado sem clube.

### D16.3 — Posição principal preenchida depois da `fato_desempenho`

`posicao_principal` e `grupo_principal` (os de mais minutos) são criadas agora, vazias, e preenchidas por `UPDATE` na aula da `fato_desempenho`, com os minutos certos (acréscimos e expulsões). Servem de rótulo e filtro ("Kanté · Volante"). O mínimo de 900 minutos continua sendo **no grupo** (D6.3), por medida DAX sobre a fato.

**Descartadas:** *calcular agora pela contagem de trechos*: quem entra aos 85 minutos contaria como um jogo inteiro; *sem posição principal*: sem rótulo na lista de jogadores.

### D16.4 — Colunas do Transfermarkt criadas agora, preenchidas no Bloco 2

`tm_player_id`, `data_nascimento`, `idade_2016` (em 01/07/2016, D6.6), `pe` e `altura_cm` são criadas vazias e preenchidas por `UPDATE` depois da ligação. `sb_player_id` e `tm_player_id` ficam únicos por índice filtrado, porque no Bloco 2 entram os jogadores do Chelsea 2014/15 que não estão no StatsBomb (D10.3), com `sb_player_id` NULL.

**Descartada:** *criar as colunas só no Bloco 2* (refazendo o `CREATE` ou com `ALTER TABLE`): mexe de novo na estrutura de uma tabela já carregada.

---

## D17 — `fato_desempenho`: minutos, ligação dos lances, trechos, colunas e posição principal

**Contexto** (2026-11-10, medido no banco antes de decidir, sem alterar nada):

| Medição | Resultado |
|---|---|
| Grão jogador × partida × posição | 54.415 linhas (56.884 trechos; quem volta à mesma posição na partida conta uma vez) |
| Lances com jogador cuja `position_id` bate com um trecho dele na partida | 5.301.052 de 5.301.066; os 14 restantes são cartões ("Bad Behaviour") de quem estava no banco |
| Expulsos (vermelho ou segundo amarelo) | 413; em 406 o trecho vai até o apito, e nenhum tem lance depois do cartão (9.663 minutos a mais) |
| Minutos pelo método do levantamento (relógio, fim = último lance da partida) | 3.131.179: perde o acréscimo do 1º tempo, porque o relógio do 2º tempo recomeça em 45:00 |
| Minutos por tempo, com os dois acréscimos | 3.175.569 (+44 mil, 1,4%); duração média de 95,2 minutos |
| Com o corte dos expulsos | 3.165.906 |
| Jogadores em campo por jogo × time | 2.937 normais; 65 abaixo de 10,5, todos com expulsão; 32 acima de 11 por erro da origem (ex.: Waguè, Udinese, sai lesionado e a escalação registra a volta dele junto com a entrada do Heurtaux) |
| Posse (participação nos passes, sem lateral) | Chelsea 56%, Barcelona 67%, Leicester 42%; fator do PAdj de 0,64 a 2,25 |
| Posição × grupo de mais minutos | Em 68 jogadores o grupo da posição de mais minutos não é o grupo de mais minutos (Kenedy: Lateral esquerdo é a posição de mais minutos, mas soma mais em Ponta) |

### D17.1 — Minutos por tempo, com os dois acréscimos e o corte dos expulsos

O fim de cada tempo é o último lance daquele período. Um trecho que começa no 1º tempo soma `fim do 1º tempo − início` e `fim do trecho − 45:00` no 2º. Sem hora de fim, vai até o fim do 2º tempo. O trecho ativo de quem levou vermelho ou segundo amarelo (coluna `card`, D8) termina no minuto do cartão. Os 32 jogos × time com sobreposição ficam como vieram e são registrados como erro da origem (algumas centenas de minutos).

**Descartadas:** *método do levantamento*: perde 1,4% dos minutos e não corta os expulsos; *por tempo sem o corte*: 406 expulsos com 9.663 minutos fora de campo, o que derruba o "por 90" deles.

### D17.2 — Lance ligado à linha pela posição do próprio evento

Cada lance cai na linha jogador × partida × posição pela `position_id` gravada no evento: 99,9997% batem com um trecho. Os 14 cartões de quem estava no banco ficam fora.

**Descartada:** *pelo horário do lance dentro do trecho*: muito mais SQL para o mesmo resultado.

### D17.3 — Tabela intermediária `stg.sb_trechos`

Uma linha por trecho (56.884), com os segundos de início e fim já com o corte dos expulsos e os minutos do trecho. É conferida sozinha (jogadores em campo por jogo × time), segue a D10 (intermediários na `stg`) e é reaproveitada no `UPDATE` da posição principal e no SSIS.

**Descartada:** *tudo em CTEs na carga da fato*: sem tabela a mais, mas um script enorme e difícil de conferir.

### D17.4 — Colunas da fato e PAdj no ETL

| Grupo | Colunas |
|---|---|
| Chaves | `sk_jogador`, `sk_partida`, `sk_posicao` (PK nas três), `sk_time`, `sk_liga`, `sk_data` |
| Tempo | `minutos` |
| Passe | `passes`, `passes_certos`, `passes_progressivos`, `passes_chave`, `passes_area` |
| Condução e drible | `conducoes_progressivas`, `dribles`, `dribles_certos` |
| Defesa | `desarmes_ganhos`, `interceptacoes`, `recuperacoes`, `pressoes`, `duelos_aereos_ganhos`, `duelos_aereos_perdidos` |
| Erros | `perdas_bola`, `erros_levaram_chute` |
| Ataque (visão por setor) | `chutes`, `gols`, `xg`, `assistencias` |
| PAdj (D6.5) | `desarmes_padj`, `interceptacoes_padj`, `recuperacoes_padj`, `pressoes_padj` = contagem × 0,5 / (1 − posse do time na partida) |

A partida já leva ao time, à liga e à data, mas as chaves diretas deixam a estrela simples no SSAS e no Power BI. A posse vira a coluna `posse` da `dw.dim_partida` (grão partida × time), por `ALTER TABLE` + `UPDATE`. As regras de cada indicador são as do levantamento (`00_dados/levantamento/Levantamento.cs`): passe sem lateral; certo = sem `pass_outcome`; passe-chave = assistência para chute ou gol; passe na área = certo, de fora para dentro da área; passe progressivo pela D6.5; condução progressiva = termina com x ≥ 60, 25% mais perto do gol e avança pelo menos 5; desarme e interceptação com resultado Won / Success In Play / Success Out; recuperação sem falha; perda = Dispossessed + Miscontrol; duelo aéreo ganho pelo `aerial_won` e perdido pelo `Aerial Lost`.

**Descartadas:** *só as contagens brutas e a posse, com o ajuste no DAX* (`SUMX` linha a linha): flexível, mas foge da D6.5 e pesa no modelo; *só os valores ajustados*: perde o número bruto.

### D17.5 — Grupo principal primeiro, posição principal dentro dele

`grupo_principal` = grupo com mais minutos; `posicao_principal` = posição com mais minutos dentro desse grupo. Os dois ficam sempre coerentes (Kenedy: Ponta).

**Descartada:** *posição de mais minutos e o grupo dela*: em 68 jogadores o grupo não seria o de mais minutos.

**Ordem das aulas:** 16 `stg.sb_trechos`; 17 coluna `posse` + `fato_desempenho`; 18 `UPDATE` da posição principal e validação contra o levantamento (percentis de Terry e Cahill em passe progressivo).

**Validação** (Aula 18, 2026-11-10): as contagens da fato para Terry, Cahill e Matić são iguais às do levantamento em todos os indicadores; só os minutos mudam (acréscimos e corte). Entre os 62 zagueiros da Premier League com 900+ minutos no grupo, o percentil em passe progressivo por 90 ficou Terry 0, Cahill 2 e Zouma 5 (levantamento: 0, 0 e 5): o achado da D5 se mantém. Com o PAdj, o Chelsea passa de 20º para 14º em interceptações por jogo, então parte do último lugar era efeito da posse (56%). O Kanté tem 1.722 minutos de Meia central e 1.408 de Volante: o rótulo principal é "Meia central", mas ele entra na comparação dos dois grupos (mínimo de 900 por grupo, D6.3).

---

## D18 — Ligação dos jogadores StatsBomb × Transfermarkt: regras, exceções e resultado

**Contexto** (2026-11-10, medido no banco antes de decidir, sem alterar nada): o StatsBomb tem 2.279 pares jogador × time (2.176 jogadores; os 103 que trocaram de time aparecem duas vezes). No Transfermarkt, 2.374 jogadores atuaram pelos 80 clubes em 2015/16. As regras da D10.1, sem acento (`COLLATE Latin1_General_100_CI_AI`), dentro do clube na temporada e só quando há um candidato de cada lado:

| Regra | Pares | % dos minutos (acumulado) |
|---|---|---|
| 1. Nome TM = apelido SB | 2.136 | |
| 2. Nome TM = nome completo SB | 10 | |
| 3. Último sobrenome igual | 57 | 97,01% |
| 4. Todas as palavras do nome TM aparecem no apelido + nome completo SB (hífen separa palavras, ponto sai) | 54 | 99,30% |

Nenhum jogador ficou com dois `tm_player_id` (os 103 que trocaram de time caíram no mesmo jogador nos dois clubes) e em nenhum dos 2.257 pares a diferença de minutos de liga entre as fontes passa de 25% + 90. A regra 4 resolve o Mikel (`John Obi Mikel` × `Mikel John Obi`), "Juanfran Torres", "Adrián San Miguel", "Emmanuel Badu". Sobram 22: 4 com a letra sérvia `Đ` (o `CI_AI` não a troca por "Dj"), 14 apelidos diferentes (Xabi Etxeita, Juankar, Chicharito...), 2 mudanças de nome (Jiang Guangtai = Tyias Browning, naturalizado chinês; Assane Gnoukouri = "Alassane Traoré" no TM, mesma data de nascimento, 28/09/1996) e 2 sem atuação no TM em 2015/16 (Markel Susaeta, Rushian Hepburn-Murphy, que existem na `tm_players`). O StatsBomb também grava `David N"Gog` e `Charles N"Zogbia` com aspas duplas no lugar do apóstrofo.

### D18.1 — Regras 1 a 3 da D10.1 + regra 4 + `Đ` → `Dj`

A regra 4 entra depois das três da D10.1. Antes de comparar, `Đ`/`đ` viram `Dj`/`dj` nos nomes do StatsBomb (Đoković = Djokovic). Ficam 18 casos para a lista de exceções.

**Descartadas:** *só as regras da D10.1*: 97,01%, abaixo da meta de 98%, e 76 casos à mão; *`JARO_WINKLER_SIMILARITY`*: já descartada na D10 (exige `PREVIEW_FEATURES`).

### D18.2 — Exceções numa lista `VALUES` no script (revê a D10.1)

Cada exceção é uma linha com `sb_player_id`, `tm_player_id` e o motivo, no próprio script de carga, como os grupos da `dim_posicao`. Fica versionada no repositório e o SQL Server não precisa ler nenhum arquivo novo.

**Descartadas:** *CSV no repositório* (D10.1): o serviço do SQL Server só lê `C:\dados` (D7), então seria preciso copiar o arquivo ou dar permissão na pasta do OneDrive; *CSV em `C:\dados`*: fora do Git.

### D18.3 — Aspas duplas viram apóstrofo na `dim_jogador`

A regra do apóstrofo da D16 passa a trocar também `"` por `'` ("David N'Gog", "Charles N'Zogbia"): uma linha a mais na carga e um `UPDATE` de 2 linhas no banco.

**Descartada:** *deixar como veio*: "David N"Gog" nos relatórios.

### D18.4 — Tabela `stg.ligacao_jogadores` + `UPDATE` do `tm_player_id`

Uma linha por par jogador × time do StatsBomb (`sb_player_id`, `sb_team_id`, `tm_player_id`, `tm_club_id`, `regra`, com regra 5 = exceção). Depois, o `UPDATE` do `tm_player_id` na `dim_jogador`. A coluna `regra` permite auditar e é o que o SSIS compara por `EXCEPT` (D10.1).

**Descartada:** *`UPDATE` direto na `dim_jogador`*: mais curto, mas perde a regra de cada par e a comparação com o SSIS.

---

## D19 — Resto do Bloco 2: `dim_jogador`, clubes e jogos do Transfermarkt e o recorte das 3 fatos

**Contexto** (2026-11-10, medido no banco antes de decidir, sem alterar nada): o universo do Transfermarkt no DW tem 2.181 jogadores, os 2.176 ligados (D18) mais 5 do elenco do Chelsea 2014/15 que não jogaram em 2015/16 (Drogba 1.317 min, Schürrle 664, Christensen 102, Solanke 17, Izzy Brown 11; os outros 21 do elenco já estão entre os ligados). De 2014 a 2026 eles têm 329.797 atuações em 43.457 jogos (68.504 jogo × clube, 3.034 já na `dim_partida`; todas as competições já na `dim_liga`), 46.741 avaliações e 5.717 transferências. Os clubes usados como chave nas fatos são 963 (883 fora da `dim_time`, só 537 na `tm_clubs`); com os adversários seriam 1.676. Nos 2.176 ligados há data de nascimento em 2.175, pé em 2.160 e altura em 2.166. As transferências cobrem só 762 dos 2.181 jogadores (16 dos 28 do Chelsea, nenhuma do David Luiz); das 5.717, 1.389 têm taxa paga, 3.482 taxa 0 (empréstimo, fim de contrato) e 846 sem informação. A janela de 2016 do Chelsea está lá: Kanté €35,8 mi, Batshuayi €39 mi, Alonso €23 mi.

### D19.1 — `dim_jogador`: atributos do TM + 5 jogadores do Chelsea 2014/15

`UPDATE` de `data_nascimento`, `idade_2016` (em 01/07/2016, D6.6), `pe` em português (Direito, Esquerdo, Ambos) e `altura_cm`. `INSERT` dos 5 do Chelsea 2014/15 com `sb_player_id` NULL e nome do TM, para a visão por setor 14/15 × 15/16 (D5).

**Descartada:** *só o `UPDATE`*: a visão 14/15 perderia o Drogba e o Schürrle.

### D19.2 — `dim_time`: os 963 clubes usados como chave nas fatos

Entram o clube do jogador em cada atuação, os clubes de origem e destino das transferências e o clube na data da avaliação. Nome da `tm_clubs` ou, quando falta, o nome mais frequente nas fatos. Os "clubes" especiais do TM entram traduzidos ("Without Club" = "Sem clube", "Retired" = "Aposentado").

**Descartadas:** *com os adversários* (1.676): a `dim_partida` já guarda o adversário como texto (D15); *só os clubes das atuações*: as transferências ficariam com clube em texto, fora da estrela.

### D19.3 — `dim_partida`: só o lado do clube do jogador

65.470 linhas novas (68.504 no total), no grão partida × time da D15. Rodada tirada de "N. Matchday" (35.317 dos 43.457 jogos; jogo de copa fica sem rodada); posse e chaves do StatsBomb NULL.

**Descartada:** *os dois lados de cada jogo* (86.914): metade das linhas sem nenhum jogador do DW.

### D19.4 — Fatos a partir de 2014 (D10.3)

| Fato | Linhas | Conteúdo |
|---|---|---|
| `fato_atuacao` | 329.797 | Minutos, gols, assistências, amarelos, vermelhos (2014/15 a 2025/26) |
| `fato_valor_mercado` | 46.741 | Valor em cada avaliação; só 3 jogadores ficam sem valor até 30/06/2016, porque a última avaliação deles é anterior a 2014 |
| `fato_transferencia` | 5.717 | Origem, destino, taxa (NULL = não informada, separada de 0 = sem custo), valor de mercado na data |

Limitação registrada: o dataset só tem transferências de 762 dos 2.181 jogadores (nenhuma do David Luiz). Na Validação, a mudança de clube depois de 2016 aparece também nas atuações (o David Luiz joga pelo Chelsea em 2016/17).

**Descartada:** *avaliações desde 2004* (65.909): exigiria aumentar a `dim_data` (revê a D11.3) para salvar 3 valores.

**Ordem das aulas:** 20 `dim_jogador`; 21 `dim_time` e `dim_partida`; 22 `fato_atuacao`; 23 `fato_valor_mercado` e `fato_transferencia`.
