-- =====================================================================
-- Projeto: Chelsea 2015/16 — Scouting e Recrutamento
-- Arquivo: 01_sql/02_carga_statsbomb.sql
-- Objetivo: carregar os JSONs do StatsBomb (C:\dados\chelsea_scouting\
--           statsbomb) nas tabelas stg.sb_* com OPENROWSET + OPENJSON
--           (D7.1), sem conversão fora do SQL Server.
--
-- O arquivo é montado aula a aula, junto com a carga no SSMS:
--   [x] stg.sb_matches   Premier League (2_27.json)              Aula 5
--   [ ] stg.sb_matches   La Liga, Serie A e Ligue 1 (laço)
--   [ ] stg.sb_lineups   1.517 arquivos lineups\<match_id>.json
--   [ ] stg.sb_events    1.517 arquivos events\<match_id>.json
--
-- Como funciona:
--   * OPENROWSET(BULK ..., SINGLE_BLOB) devolve o arquivo inteiro numa
--     linha só (coluna BulkColumn). Quem lê é o serviço do SQL Server:
--     precisa da permissão de leitura do NT Service\MSSQLSERVER na pasta
--     (docs/dados.md).
--   * CAST(BulkColumn AS varchar(max)) acerta os acentos porque o banco
--     foi criado com collation UTF-8 (00_criar_bancos.sql).
--   * OPENJSON ... WITH: cada objeto da lista vira uma linha; o caminho
--     '$.a.b' entra nos níveis do JSON e [0] pega o 1º item de uma lista.
--     Campo ausente vira NULL (modo lax, o padrão).
--   * TRUNCATE antes do INSERT: o script pode rodar de novo sem duplicar.
--     Se mesmo assim vier match_id repetido, a chave primária barra o
--     INSERT inteiro (tudo ou nada).
--
-- Rodar com (depois do 01_staging_tabelas.sql):
--   sqlcmd -S localhost -E -C -f 65001 -i 01_sql\02_carga_statsbomb.sql
-- =====================================================================

USE chelsea_scouting;
GO

SET NOCOUNT ON;

-- ---------------------------------------------------------------------
-- stg.sb_matches: Premier League 2015/16
-- Conferido em 2026-11-06: 380 partidas, 1.026 gols, Chelsea 59 pró e
-- 53 contra em 38 jogos (igual ao levantamento e ao Transfermarkt).
-- Técnicos do Chelsea: Mourinho 16 jogos (até 14/12), Steve Holland 1
-- (interino, 19/12) e Hiddink 21. O nickname do Hiddink vem NULL: nas
-- dimensões, usar COALESCE(nickname, name).
-- ---------------------------------------------------------------------
TRUNCATE TABLE stg.sb_matches;

INSERT INTO stg.sb_matches
SELECT m.*
FROM OPENROWSET(BULK 'C:\dados\chelsea_scouting\statsbomb\matches\2_27.json', SINGLE_BLOB) AS arq
CROSS APPLY OPENJSON(CAST(arq.BulkColumn AS varchar(max)))
WITH (
    match_id               INT           '$.match_id',
    match_date             DATE          '$.match_date',
    kick_off               TIME(3)       '$.kick_off',
    competition_id         INT           '$.competition.competition_id',
    competition_name       NVARCHAR(50)  '$.competition.competition_name',
    country_name           NVARCHAR(50)  '$.competition.country_name',
    season_id              INT           '$.season.season_id',
    season_name            NVARCHAR(20)  '$.season.season_name',
    match_week             INT           '$.match_week',
    competition_stage      NVARCHAR(50)  '$.competition_stage.name',
    home_team_id           INT           '$.home_team.home_team_id',
    home_team_name         NVARCHAR(100) '$.home_team.home_team_name',
    home_manager_id        INT           '$.home_team.managers[0].id',
    home_manager_name      NVARCHAR(150) '$.home_team.managers[0].name',
    home_manager_nickname  NVARCHAR(100) '$.home_team.managers[0].nickname',
    away_team_id           INT           '$.away_team.away_team_id',
    away_team_name         NVARCHAR(100) '$.away_team.away_team_name',
    away_manager_id        INT           '$.away_team.managers[0].id',
    away_manager_name      NVARCHAR(150) '$.away_team.managers[0].name',
    away_manager_nickname  NVARCHAR(100) '$.away_team.managers[0].nickname',
    home_score             INT           '$.home_score',
    away_score             INT           '$.away_score',
    stadium_name           NVARCHAR(150) '$.stadium.name',
    referee_name           NVARCHAR(150) '$.referee.name',
    data_version           NVARCHAR(10)  '$.metadata.data_version'
) AS m;
GO

-- ---------------------------------------------------------------------
-- Conferência: partidas, gols da liga e gols do Chelsea
-- Esperado (PL): 380 | 1026 | 59 | 53
-- ---------------------------------------------------------------------
SELECT COUNT(*)                         AS partidas,
       SUM(home_score + away_score)     AS gols_liga,
       SUM(CASE WHEN home_team_name = 'Chelsea' THEN home_score
                WHEN away_team_name = 'Chelsea' THEN away_score END) AS chelsea_pro,
       SUM(CASE WHEN home_team_name = 'Chelsea' THEN away_score
                WHEN away_team_name = 'Chelsea' THEN home_score END) AS chelsea_contra
FROM stg.sb_matches;
GO
