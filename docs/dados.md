# Dados do projeto

De onde vêm os dados, onde ficam, como são lidos e como reproduzir tudo do zero.

---

## 1. Fontes

| Fonte | O que traz | Recorte usado | Formato | Licença |
|---|---|---|---|---|
| [StatsBomb Open Data](https://github.com/statsbomb/open-data) | Eventos lance a lance (passes, conduções, dribles, desarmes, pressões, chutes com xG) e escalações com minutos por posição | Temporada 2015/16 (`season_id = 27`). Hoje: Premier League (`competition_id = 2`), 380 partidas | JSON | Gratuita, com atribuição obrigatória à StatsBomb |
| [Transfermarkt Datasets](https://github.com/dcaribou/transfermarkt-datasets) (dcaribou) | Resultados, atuações (minutos, gols, assistências), jogadores, valores de mercado e transferências | Premier League (`GB1`) 2014/15 e 2015/16, valores de 2015 a 2016 | CSV compactado (`.csv.gz`) | CC0 (domínio público) |

Endereços usados no download:
- StatsBomb: `https://raw.githubusercontent.com/statsbomb/open-data/master/data/<matches|events|lineups>/...`
- Transfermarkt: `https://pub-e682421888d945d684bcae8890b0ec20.r2.dev/data/<tabela>.csv.gz` (as atualizações do dataset estão pausadas desde 06/07/2026)

As duas fontes não têm ID de jogador em comum. A ligação entre elas (nome, data de nascimento, clube) vai ser feita numa etapa própria.

---

## 2. Onde os dados ficam

Os dados brutos **não estão no repositório**. Ficam em `C:\dados\chelsea_scouting`, fora do Git e fora do OneDrive (decisão D4 em [`decisoes.md`](decisoes.md)): só os eventos da Premier League ocupam ~1,1 GB, e as 4 ligas previstas somam ~4,6 GB.

```
C:\dados\chelsea_scouting\
├── statsbomb\
│   ├── matches\2_27.json      lista das 380 partidas da Premier League 2015/16
│   ├── events\<match_id>.json eventos de cada partida (380 arquivos, ~1,05 GB)
│   └── lineups\<match_id>.json escalações (380 arquivos)
├── transfermarkt\<tabela>.csv.gz  as 12 tabelas do dataset
└── levantamento\              saídas dos scripts de levantamento (CSV)
```

O que vai para o GitHub são os **scripts** que baixam e leem esses dados. Qualquer pessoa consegue refazer tudo com eles.

---

## 3. Como reproduzir

Requisitos: Windows com PowerShell 5.1 (já vem no Windows). Não precisa de Python.

**Passo 1: baixar os dados** (~1,1 GB, alguns minutos)
```powershell
.\00_dados\baixar_dados.ps1
```
Para as 4 ligas: `.\00_dados\baixar_dados.ps1 -Ligas 2,11,12,7`. Arquivos já baixados são pulados.

**Passo 2: rodar o levantamento** (cerca de 2 minutos no total)
```powershell
.\00_dados\levantamento\1_resumir_statsbomb.ps1
.\00_dados\levantamento\2_chelsea_transfermarkt.ps1
.\00_dados\levantamento\3_comparar_liga.ps1
.\00_dados\levantamento\4_percentis_jogadores.ps1
```

| Script | O que faz | Saída |
|---|---|---|
| `1_resumir_statsbomb.ps1` | Lê os 380 JSONs de eventos e escalações e soma os indicadores por time, setor e jogador | `times_setores.csv`, `jogadores.csv` |
| `2_chelsea_transfermarkt.ps1` | Classificação de 2014/15 e 2015/16, minutos/gols/assistências do elenco e valor de mercado jul/2015 × jun/2016 | `tm_classificacao.csv`, `tm_chelsea_jogadores.csv`, recortes `tm_*.csv` |
| `3_comparar_liga.ps1` | Posição do Chelsea entre os 20 times em cada indicador, no total do time, no sofrido e por setor | Tabelas na tela |
| `4_percentis_jogadores.ps1` | Percentil de cada jogador do Chelsea dentro do grupo de posição na liga | `chelsea_percentis.csv` |

A leitura dos JSONs é feita em C# (`Levantamento.cs`, compilado na hora pelo próprio PowerShell), porque o `ConvertFrom-Json` do PowerShell 5.1 é lento demais para ~1 GB. Assim as 380 partidas são processadas em menos de 1 minuto.

Nas próximas etapas os dados entram no SQL Server pelo SSIS, a partir da mesma pasta.

---

## 4. Conferência

| Checagem | StatsBomb | Transfermarkt |
|---|---|---|
| Gols do Chelsea em 2015/16 (pró / contra) | 59 / 53 | 59 / 53 |
| Gols da Premier League 2015/16 | 1.026 | 1.026 |
| Partidas | 380 | 380 |

---

## 5. Definições usadas no levantamento

| Indicador | Definição |
|---|---|
| xG | `shot.statsbomb_xg` de cada chute. "Sem pênalti" exclui `shot.type = Penalty` |
| Passe-chave | Passe que terminou em chute (`pass.shot_assist` ou `pass.goal_assist`) |
| Passe na área | Passe certo que sai de fora e termina dentro da área (x ≥ 102 e 18 ≤ y ≤ 62, campo de 120 × 80) |
| Passe no último terço | Passe certo que sai de x < 80 e termina em x ≥ 80 |
| Passe progressivo | Passe certo, fora de bola parada, que termina no campo de ataque (x ≥ 60) pelo menos 25% mais perto do centro do gol do que começou |
| Condução progressiva | Mesma regra do passe progressivo, com avanço mínimo de 5 unidades em x |
| Desarme ganho | `Duel` do tipo `Tackle` com resultado `Won`, `Success In Play` ou `Success Out` |
| Recuperação | `Ball Recovery` sem `recovery_failure`. "No terço ofensivo" = x ≥ 80 |
| Perda de bola | `Dispossessed` + `Miscontrol` |
| Duelo aéreo | Ganho = `aerial_won` em passe, chute, corte ou domínio. Perdido = `Duel` do tipo `Aerial Lost` |
| Setor | Pela posição do jogador no lance: `Goalkeeper` → Goleiro, `* Back` → Defesa, `* Midfield` → Meio, pontas e atacantes → Ataque |
| Minutos | Pelas escalações (`positions.from`/`to`). Quando `to` está vazio, conta até o último lance da partida, com acréscimos |
| Posse | Participação do time no total de passes da partida (aproximação) |

Arremessos laterais não contam como passe. As posições do Transfermarkt são as atuais do jogador, não as de 2015; para posição, vale o StatsBomb.

---

## 6. Atribuição

Os dados de eventos são da **StatsBomb**. Todo material publicado com eles (dashboards, prints, posts) precisa citar a StatsBomb como fonte e usar o logo do [Media Pack](https://github.com/statsbomb/open-data). Os dados do Transfermarkt Datasets são CC0, mas o projeto cita a fonte do mesmo jeito.
