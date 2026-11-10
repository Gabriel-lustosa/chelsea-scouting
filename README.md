# Chelsea 2015/16 — Scouting e Recrutamento

![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?style=flat&logo=microsoftsqlserver&logoColor=white)
![SSIS](https://img.shields.io/badge/SSIS-CC2927?style=flat)
![SSAS Tabular](https://img.shields.io/badge/SSAS%20Tabular-CC2927?style=flat)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![Status](https://img.shields.io/badge/status-em%20andamento-yellow?style=flat)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Gabriel%20Lustosa-0A66C2?style=flat&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/gabriellustosa1/)

Projeto de portfólio em **Business Intelligence** aplicado ao futebol: diagnosticar jogadores que não renderam na função e recomendar contratações no mercado, usando dados de eventos lance a lance e dados de mercado.

---

## Objetivo de negócio

O Chelsea foi campeão em 2014/15 e terminou a temporada 2015/16 em **10º lugar**. O projeto se coloca na diretoria do clube antes da janela de transferências de 2016 e responde a três perguntas:

1. **Diagnóstico:** quais jogadores renderam abaixo do esperado para a função, comparados com os jogadores da mesma posição nas grandes ligas?
2. **Mercado:** quem, nas grandes ligas, tem um perfil parecido, números melhores e cabe no orçamento?
3. **Validação:** as recomendações se confirmaram? A comparação usa o que aconteceu de fato com esses jogadores depois de 2016.

---

## Fontes de dados

| Fonte | Papel | Licença |
|---|---|---|
| [StatsBomb Open Data](https://github.com/statsbomb/open-data) | Eventos lance a lance de 2015/16: Premier League, La Liga, Serie A e Ligue 1 | Gratuita, citando a StatsBomb |
| [Transfermarkt Datasets](https://github.com/dcaribou/transfermarkt-datasets) | Valores de mercado, contratos, transferências e atuações | CC0 |

Os dados brutos **não estão** no repositório: ficam em `C:\dados\chelsea_scouting` (~4,3 GB de eventos das 4 ligas). O repositório guarda os scripts que baixam e leem esses dados. Detalhes, conferência dos números e definições dos indicadores em [`docs/dados.md`](docs/dados.md).

---

## Como rodar

Windows com PowerShell 5.1. Não precisa de Python.

```powershell
# 1. Baixar os dados das 4 ligas (~4,3 GB, para C:\dados\chelsea_scouting)
.\00_dados\baixar_dados.ps1 -Ligas 2,11,12,7

# 2. Levantamento: onde o Chelsea caiu em 2015/16
.\00_dados\levantamento\1_resumir_statsbomb.ps1
.\00_dados\levantamento\2_chelsea_transfermarkt.ps1
.\00_dados\levantamento\3_comparar_liga.ps1
.\00_dados\levantamento\4_percentis_jogadores.ps1

# 3. Criar os bancos (SQL Server local)
sqlcmd -S localhost -E -C -f 65001 -i 01_sql\00_criar_bancos.sql

# 4. Criar a staging e carregar o StatsBomb
sqlcmd -S localhost -E -C -f 65001 -i 01_sql\01_staging_tabelas.sql
sqlcmd -S localhost -E -C -f 65001 -i 01_sql\02_carga_statsbomb.sql
```

As etapas de SQL Server, SSIS, SSAS e Power BI entram aqui conforme forem construídas.

---

## Estrutura

```
00_dados/        download dos dados e scripts do levantamento
01_sql/          DW em T-SQL: bancos, staging, dimensões e fatos
docs/            log de decisões e documentação dos dados
```

---

## Decisões do projeto

Cada etapa foi decidida entre alternativas, e o motivo de cada escolha está registrado em [`docs/decisoes.md`](docs/decisoes.md).

---

## Status

| Etapa | Status |
|---|---|
| Escolha das fontes, do clube e do local dos dados | Pronto |
| Levantamento: onde o Chelsea caiu | Pronto |
| Escopo: zagueiro, volante e lateral; depois, visão por setor | Pronto |
| Desenho do modelo estrela | Pronto |
| Desenho da carga: OPENJSON no SQL Server | Pronto |
| Download dos dados (4 ligas, 1.517 partidas) | Pronto |
| Criação dos bancos e carga da staging | Pronto (10 tabelas da staging criadas; carga das partidas das 4 ligas feita: 1.517; escalações: 56.884 linhas; eventos: 5.321.459, com cartões e xG exato, D8 e D9; Transfermarkt: 7 tabelas, 2,9 milhões de linhas) |
| Desenho do DW: ligação em SQL, dois blocos (D10) | Pronto |
| DW no SQL Server | Em andamento (Bloco 1 StatsBomb completo: 6 dimensões + `fato_desempenho` com 54.415 linhas, validada contra o levantamento; Bloco 2 Transfermarkt em andamento: jogadores ligados, 2.279 pares, 100% dos minutos; `dim_jogador` com 2.181 jogadores e os atributos do TM; `dim_time` com 943 clubes e `dim_partida` com 68.504 linhas) |
| ETL com SSIS | Pendente |
| Modelo SSAS Tabular | Pendente |
| Dashboards Power BI | Pendente |

---

*Dados de eventos: StatsBomb. Projeto desenvolvido por [Gabriel Lustosa](https://github.com/Gabriel-lustosa) como portfólio pessoal de BI/Analytics.*
