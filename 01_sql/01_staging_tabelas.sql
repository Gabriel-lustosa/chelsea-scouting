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
--     [x] stg.sb_matches   1 linha por partida   (matches\<liga>_27.json)
--     [x] stg.sb_lineups   1 linha por jogador x trecho em uma posição
--     [x] stg.sb_events    1 linha por evento, colunas achatadas (D7.2)
--   Transfermarkt (CSV, lido com BULK INSERT, D7.3)
--     [x] stg.tm_competitions, tm_clubs, tm_players, tm_games,
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

-- ---------------------------------------------------------------------
-- stg.sb_events: ~5 milhões de eventos, só as colunas que os
-- indicadores da D6.5 usam (D7.2). Nome = caminho no JSON com "_"
-- (ex.: pass.end_location[0] -> pass_end_location_x).
-- match_id não está no lance: vem do nome do arquivo (<match_id>.json).
-- Chave = (match_id, event_index): grava os lances em ordem no disco.
-- O id (GUID) é único, mas aleatório: como chave, espalharia as linhas.
-- DECIMAL em vez de FLOAT: soma exata do xG nas conferências.
-- BIT: o StatsBomb só manda o campo quando é verdade; ausente = NULL.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS stg.sb_events;
CREATE TABLE stg.sb_events (
    match_id                        INT              NOT NULL,
    event_index                     INT              NOT NULL,   -- campo "index"
    id                              UNIQUEIDENTIFIER NOT NULL,
    period                          INT              NOT NULL,
    [timestamp]                     TIME(3)          NULL,       -- [ ]: timestamp é nome de tipo antigo
    minute                          INT              NOT NULL,
    second                          INT              NOT NULL,
    type_id                         INT              NOT NULL,
    type_name                       NVARCHAR(50)     NOT NULL,
    possession                      INT              NULL,
    possession_team_id              INT              NULL,
    play_pattern                    NVARCHAR(50)     NULL,
    team_id                         INT              NOT NULL,
    player_id                       INT              NULL,       -- vazio em eventos do time (ex.: Half Start)
    position_id                     INT              NULL,
    location_x                      DECIMAL(5,2)     NULL,       -- campo de 120 x 80
    location_y                      DECIMAL(5,2)     NULL,
    under_pressure                  BIT              NULL,
    counterpress                    BIT              NULL,
    -- passe
    pass_end_location_x             DECIMAL(5,2)     NULL,
    pass_end_location_y             DECIMAL(5,2)     NULL,
    pass_outcome                    NVARCHAR(50)     NULL,       -- vazio = passe certo
    pass_type                       NVARCHAR(50)     NULL,       -- Corner, Free Kick, Throw-in...
    pass_height                     NVARCHAR(50)     NULL,
    pass_cross                      BIT              NULL,
    pass_shot_assist                BIT              NULL,
    pass_goal_assist                BIT              NULL,
    -- condução
    carry_end_location_x            DECIMAL(5,2)     NULL,
    carry_end_location_y            DECIMAL(5,2)     NULL,
    -- drible, duelo, interceptação, recuperação
    dribble_outcome                 NVARCHAR(50)     NULL,
    duel_type                       NVARCHAR(50)     NULL,
    duel_outcome                    NVARCHAR(50)     NULL,
    interception_outcome            NVARCHAR(50)     NULL,
    ball_recovery_recovery_failure  BIT              NULL,
    -- aerial_won aparece em pass, shot, clearance e miscontrol: junta os 4
    aerial_won                      BIT              NULL,
    -- chute
    shot_statsbomb_xg               DECIMAL(9,8)     NULL,
    shot_type                       NVARCHAR(50)     NULL,       -- Open Play, Penalty, Free Kick...
    shot_outcome                    NVARCHAR(50)     NULL,
    CONSTRAINT pk_sb_events PRIMARY KEY (match_id, event_index)
);
GO

-- =====================================================================
-- TRANSFERMARKT (espelho 1:1 dos CSVs, mesma ordem de colunas)
-- =====================================================================

DROP TABLE IF EXISTS stg.tm_competitions;
CREATE TABLE stg.tm_competitions (
    competition_id        NVARCHAR(10)  NOT NULL PRIMARY KEY,   -- GB1, ES1, IT1, FR1...
    competition_code      NVARCHAR(100) NULL,
    name                  NVARCHAR(100) NULL,
    sub_type              NVARCHAR(50)  NULL,
    type                  NVARCHAR(50)  NULL,
    country_id            INT           NULL,
    country_name          NVARCHAR(100) NULL,
    domestic_league_code  NVARCHAR(10)  NULL,
    confederation         NVARCHAR(50)  NULL,
    total_clubs           INT           NULL,
    url                   NVARCHAR(400) NULL
);

DROP TABLE IF EXISTS stg.tm_clubs;
CREATE TABLE stg.tm_clubs (
    club_id                  INT           NOT NULL PRIMARY KEY,
    club_code                NVARCHAR(100) NULL,
    name                     NVARCHAR(200) NULL,
    domestic_competition_id  NVARCHAR(10)  NULL,
    total_market_value       NVARCHAR(50)  NULL,
    squad_size               INT           NULL,
    average_age              DECIMAL(4,1)  NULL,
    foreigners_number        INT           NULL,
    foreigners_percentage    DECIMAL(5,1)  NULL,
    national_team_players    INT           NULL,
    stadium_name             NVARCHAR(200) NULL,
    stadium_seats            INT           NULL,
    net_transfer_record      NVARCHAR(50)  NULL,   -- texto, ex.: "+€5.90m"
    coach_name               NVARCHAR(150) NULL,
    last_season              INT           NULL,
    filename                 NVARCHAR(400) NULL,
    url                      NVARCHAR(400) NULL
);

-- Atenção: posição e contrato são os ATUAIS (2026), não os de 2016 (D6.6)
DROP TABLE IF EXISTS stg.tm_players;
CREATE TABLE stg.tm_players (
    player_id                             INT           NOT NULL PRIMARY KEY,
    first_name                            NVARCHAR(100) NULL,
    last_name                             NVARCHAR(150) NULL,
    name                                  NVARCHAR(200) NULL,
    last_season                           INT           NULL,
    current_club_id                       INT           NULL,
    player_code                           NVARCHAR(200) NULL,
    country_of_birth                      NVARCHAR(100) NULL,
    city_of_birth                         NVARCHAR(150) NULL,
    country_of_citizenship                NVARCHAR(100) NULL,
    date_of_birth                         DATETIME2(0)  NULL,
    sub_position                          NVARCHAR(50)  NULL,
    position                              NVARCHAR(50)  NULL,
    foot                                  NVARCHAR(10)  NULL,
    height_in_cm                          INT           NULL,
    contract_expiration_date              DATETIME2(0)  NULL,
    agent_name                            NVARCHAR(200) NULL,
    image_url                             NVARCHAR(400) NULL,
    international_caps                    INT           NULL,
    international_goals                   INT           NULL,
    current_national_team_id              INT           NULL,
    url                                   NVARCHAR(400) NULL,
    current_club_domestic_competition_id  NVARCHAR(10)  NULL,
    current_club_name                     NVARCHAR(200) NULL,
    market_value_in_eur                   BIGINT        NULL,
    highest_market_value_in_eur           BIGINT        NULL
);

DROP TABLE IF EXISTS stg.tm_games;
CREATE TABLE stg.tm_games (
    game_id                 INT           NOT NULL PRIMARY KEY,
    competition_id          NVARCHAR(10)  NULL,
    season                  INT           NULL,   -- 2015 = temporada 2015/16
    round                   NVARCHAR(100) NULL,
    date                    DATE          NULL,
    home_club_id            INT           NULL,
    away_club_id            INT           NULL,
    home_club_goals         INT           NULL,
    away_club_goals         INT           NULL,
    home_club_position      INT           NULL,
    away_club_position      INT           NULL,
    home_club_manager_name  NVARCHAR(150) NULL,
    away_club_manager_name  NVARCHAR(150) NULL,
    stadium                 NVARCHAR(200) NULL,
    attendance              INT           NULL,
    referee                 NVARCHAR(150) NULL,
    url                     NVARCHAR(400) NULL,
    home_club_formation     NVARCHAR(50)  NULL,
    away_club_formation     NVARCHAR(50)  NULL,
    home_club_name          NVARCHAR(200) NULL,
    away_club_name          NVARCHAR(200) NULL,
    aggregate               NVARCHAR(20)  NULL,
    competition_type        NVARCHAR(50)  NULL
);

DROP TABLE IF EXISTS stg.tm_appearances;
CREATE TABLE stg.tm_appearances (
    appearance_id           NVARCHAR(30)  NOT NULL PRIMARY KEY,   -- "<game_id>_<player_id>"
    game_id                 INT           NOT NULL,
    player_id               INT           NOT NULL,
    player_club_id          INT           NULL,
    player_current_club_id  INT           NULL,
    date                    DATE          NULL,
    player_name             NVARCHAR(200) NULL,
    competition_id          NVARCHAR(10)  NULL,
    yellow_cards            INT           NULL,
    red_cards               INT           NULL,
    goals                   INT           NULL,
    assists                 INT           NULL,
    minutes_played          INT           NULL
);

DROP TABLE IF EXISTS stg.tm_player_valuations;
CREATE TABLE stg.tm_player_valuations (
    player_id                            INT           NOT NULL,
    date                                 DATE          NOT NULL,
    market_value_in_eur                  BIGINT        NULL,
    current_club_name                    NVARCHAR(200) NULL,
    current_club_id                      INT           NULL,
    player_club_domestic_competition_id  NVARCHAR(10)  NULL,
    CONSTRAINT pk_tm_player_valuations PRIMARY KEY (player_id, date)
);

-- Sem chave: 118 casos de jogador com 2 transferências no mesmo dia
-- (empréstimo e volta; conferido em 2026-11-06). Há datas futuras (fim de empréstimo previsto).
DROP TABLE IF EXISTS stg.tm_transfers;
CREATE TABLE stg.tm_transfers (
    player_id            INT            NOT NULL,
    transfer_date        DATE           NULL,
    transfer_season      NVARCHAR(10)   NULL,   -- "16/17"
    from_club_id         INT            NULL,
    to_club_id           INT            NULL,
    from_club_name       NVARCHAR(200)  NULL,
    to_club_name         NVARCHAR(200)  NULL,
    transfer_fee         DECIMAL(15,3)  NULL,   -- euros; 0 = sem taxa
    market_value_in_eur  DECIMAL(15,3)  NULL,
    player_name          NVARCHAR(200)  NULL
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
