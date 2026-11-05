-- =====================================================================
-- Projeto: Chelsea 2015/16 — Scouting e Recrutamento
-- Arquivo: 01_sql/01_staging_tabelas.sql
-- Objetivo: criar as tabelas de STAGING (schema stg) do banco
--           chelsea_scouting. Elas recebem os dados brutos quase sem
--           mudança; as dimensões e fatos (schema dw, D6) saem delas.
--
-- O arquivo é montado aula a aula, junto com a criação no SSMS: cada
-- tabela entra aqui depois de criada e conferida no banco.
--
--   StatsBomb (JSON, lido com OPENJSON, D7.1)
--     [x] stg.sb_matches    1 linha por partida   (matches\<liga>_27.json)
--     [x] stg.sb_lineups   1 linha por jogador x trecho em uma posição
--     [ ] stg.sb_events     1 linha por evento, colunas achatadas (D7.2)
--   Transfermarkt (CSV, lido com BULK INSERT, D7.3)
--     [ ] stg.tm_competitions, tm_clubs, tm_players, tm_games,
--         tm_appearances, tm_player_valuations, tm_transfers
--
-- Convenções:
--   * Prefixo sb_ / tm_ diz de qual fonte veio a tabela.
--   * Nomes de colunas iguais aos da origem (campo do JSON ou coluna do
--     CSV), para rastrear qualquer número até o arquivo original. A
--     tradução para português fica nas dimensões e fatos.
--   * Tabelas do Transfermarkt espelham o CSV 1:1, na mesma ordem: o
--     BULK INSERT casa as colunas pela posição, não pelo nome.
--   * Texto como NVARCHAR (acentos e, mais adiante, o SSIS sem
--     problemas de code page). Coordenadas do campo como DECIMAL(5,2).
--   * Chave primária só onde a conferência mostrou unicidade (2026-11-04).
--     Se vier duplicata, a carga falha e avisa, em vez de duplicar números.
--   * Sem FKs na staging: a integridade fica nas fatos (igual ao Olist).
--
-- Pode rodar de novo: APAGA e recria as tabelas (staging é sempre
-- recarregável a partir de C:\dados\chelsea_scouting).
-- Rodar com:
--   sqlcmd -S localhost -E -C -f 65001 -i 01_sql\01_staging_tabelas.sql
-- =====================================================================

USE chelsea_scouting;
GO

-- =====================================================================
-- STATSBOMB
-- =====================================================================

-- ---------------------------------------------------------------------
-- stg.sb_matches: as 1.517 partidas das 4 ligas
-- Os técnicos vêm de home_team.managers[0] (permite separar Mourinho e
-- Hiddink no Chelsea).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS stg.sb_matches;
CREATE TABLE stg.sb_matches (
    match_id               INT           NOT NULL PRIMARY KEY,
    match_date             DATE          NOT NULL,
    kick_off               TIME(3)       NULL,
    competition_id         INT           NOT NULL,
    competition_name       NVARCHAR(50)  NOT NULL,
    country_name           NVARCHAR(50)  NULL,
    season_id              INT           NOT NULL,
    season_name            NVARCHAR(20)  NOT NULL,
    match_week             INT           NULL,
    competition_stage      NVARCHAR(50)  NULL,
    home_team_id           INT           NOT NULL,
    home_team_name         NVARCHAR(100) NOT NULL,
    home_manager_id        INT           NULL,
    home_manager_name      NVARCHAR(150) NULL,
    home_manager_nickname  NVARCHAR(100) NULL,
    away_team_id           INT           NOT NULL,
    away_team_name         NVARCHAR(100) NOT NULL,
    away_manager_id        INT           NULL,
    away_manager_name      NVARCHAR(150) NULL,
    away_manager_nickname  NVARCHAR(100) NULL,
    home_score             INT           NULL,
    away_score             INT           NULL,
    stadium_name           NVARCHAR(150) NULL,
    referee_name           NVARCHAR(150) NULL,
    data_version           NVARCHAR(10)  NULL
);

-- ---------------------------------------------------------------------
-- stg.sb_lineups: 1 linha por jogador x trecho em uma posição
-- Quem mudou de posição no jogo tem uma linha por trecho (position_seq
-- = ordem no array positions). Reservas que não entraram não têm
-- posição e ficam fora (0 minutos, não entram em nenhum indicador).
-- from/to viraram from_time/to_time: FROM é palavra reservada do SQL.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS stg.sb_lineups;
CREATE TABLE stg.sb_lineups (
    match_id         INT           NOT NULL,
    team_id          INT           NOT NULL,
    team_name        NVARCHAR(100) NOT NULL,
    player_id        INT           NOT NULL,
    player_name      NVARCHAR(150) NOT NULL,
    player_nickname  NVARCHAR(100) NULL,
    jersey_number    INT           NULL,
    country_name     NVARCHAR(100) NULL,
    position_seq     INT           NOT NULL,
    position_id      INT           NOT NULL,
    position         NVARCHAR(50)  NOT NULL,
    from_time        VARCHAR(10)   NULL,   -- "mm:ss" no relógio da partida
    to_time          VARCHAR(10)   NULL,   -- vazio = ficou até o fim
    from_period      INT           NULL,
    to_period        INT           NULL,
    start_reason     NVARCHAR(100) NULL,
    end_reason       NVARCHAR(100) NULL,
    CONSTRAINT pk_sb_lineups PRIMARY KEY (match_id, player_id, position_seq)
);
GO

-- ---------------------------------------------------------------------
-- Conferência: as tabelas da staging e o número de colunas de cada uma
-- ---------------------------------------------------------------------
SELECT t.name AS tabela, COUNT(c.column_id) AS colunas
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
WHERE t.schema_id = SCHEMA_ID('stg')
GROUP BY t.name
ORDER BY t.name;
GO
