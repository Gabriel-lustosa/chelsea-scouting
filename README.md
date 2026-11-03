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

Os dados brutos **não estão** no repositório: ficam em `C:\dados\chelsea_scouting` (~1,2 GB só a Premier League, ~4,6 GB as 4 ligas). As instruções de download vão entrar em *Como rodar*.

---

## Decisões do projeto

Cada etapa foi decidida entre alternativas, e o motivo de cada escolha está registrado em [`docs/decisoes.md`](docs/decisoes.md).

---

## Status

| Etapa | Status |
|---|---|
| Escolha das fontes, do clube e do local dos dados | Pronto |
| Escopo: posições e KPIs | Próxima |
| Download e preparação dos dados | Pendente |
| DW no SQL Server | Pendente |
| ETL com SSIS | Pendente |
| Modelo SSAS Tabular | Pendente |
| Dashboards Power BI | Pendente |

---

*Dados de eventos: StatsBomb. Projeto desenvolvido por [Gabriel Lustosa](https://github.com/Gabriel-lustosa) como portfólio pessoal de BI/Analytics.*
