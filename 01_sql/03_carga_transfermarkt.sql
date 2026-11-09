-- =====================================================================
-- Projeto: Chelsea 2015/16 — Scouting e Recrutamento
-- Arquivo: 01_sql/03_carga_transfermarkt.sql
-- Objetivo: carregar os 7 CSVs do Transfermarkt (C:\dados\chelsea_scouting\
--           transfermarkt\csv, descompactados pelo baixar_dados.ps1) nas
--           tabelas stg.tm_* com BULK INSERT (D7.2).
--
--   [x] stg.tm_competitions, tm_clubs, tm_players, tm_games,
--       tm_appearances, tm_player_valuations, tm_transfers     Aula 9
--
-- Como funciona:
--   * FORMAT = 'CSV' entende campo entre aspas, vírgula dentro das aspas
--     e "" como aspas dentro do texto (ex.: Stadion "Galgenwaard").
--   * FIRSTROW = 2 pula o cabeçalho; CODEPAGE = '65001' lê como UTF-8.
--   * ROWTERMINATOR = '0x0a': os CSVs terminam a linha só com LF. No
--     BULK INSERT, '\n' quer dizer CRLF; com ele (ou com '0x0d0a') a carga
--     falha com o erro 7301 ("IID_IColumnsInfo"), que não diz a causa.
--   * Campo vazio (,,) vira NULL. As colunas da staging estão na mesma
--     ordem do CSV (01_staging_tabelas.sql), então não precisa de mapa.
--   * TABLOCK trava a tabela durante a carga e deixa ela mais rápida.
--   * Como o OPENROWSET, o BULK INSERT só aceita o caminho escrito direto;
--     com 7 arquivos, ficou um comando por tabela, sem laço.
--   * TRUNCATE antes de cada carga: o script pode rodar de novo sem
--     duplicar. ID repetido barra a carga inteira da tabela (chave
--     primária).
--   * Quem lê o arquivo é o serviço do SQL Server (permissão de leitura do
--     NT Service\MSSQLSERVER na pasta, docs/dados.md).
--
-- Conferido em 2026-11-09: as 7 tabelas com o número de linhas do CSV
-- menos o cabeçalho, em ~5 s no total; acentos certos.
--
-- Rodar com (depois do 01_staging_tabelas.sql):
--   sqlcmd -S localhost -E -C -f 65001 -i 01_sql\03_carga_transfermarkt.sql
-- =====================================================================

USE chelsea_scouting;
GO

SET NOCOUNT ON;

TRUNCATE TABLE stg.tm_competitions;
BULK INSERT stg.tm_competitions
FROM 'C:\dados\chelsea_scouting\transfermarkt\csv\competitions.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
RAISERROR('tm_competitions ok', 0, 1) WITH NOWAIT;

TRUNCATE TABLE stg.tm_clubs;
BULK INSERT stg.tm_clubs
FROM 'C:\dados\chelsea_scouting\transfermarkt\csv\clubs.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
RAISERROR('tm_clubs ok', 0, 1) WITH NOWAIT;

TRUNCATE TABLE stg.tm_players;
BULK INSERT stg.tm_players
FROM 'C:\dados\chelsea_scouting\transfermarkt\csv\players.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
RAISERROR('tm_players ok', 0, 1) WITH NOWAIT;

TRUNCATE TABLE stg.tm_games;
BULK INSERT stg.tm_games
FROM 'C:\dados\chelsea_scouting\transfermarkt\csv\games.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
RAISERROR('tm_games ok', 0, 1) WITH NOWAIT;

TRUNCATE TABLE stg.tm_appearances;
BULK INSERT stg.tm_appearances
FROM 'C:\dados\chelsea_scouting\transfermarkt\csv\appearances.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
RAISERROR('tm_appearances ok', 0, 1) WITH NOWAIT;

TRUNCATE TABLE stg.tm_player_valuations;
BULK INSERT stg.tm_player_valuations
FROM 'C:\dados\chelsea_scouting\transfermarkt\csv\player_valuations.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
RAISERROR('tm_player_valuations ok', 0, 1) WITH NOWAIT;

TRUNCATE TABLE stg.tm_transfers;
BULK INSERT stg.tm_transfers
FROM 'C:\dados\chelsea_scouting\transfermarkt\csv\transfers.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
RAISERROR('tm_transfers ok', 0, 1) WITH NOWAIT;
GO

-- ---------------------------------------------------------------------
-- Conferência 1: linhas carregadas x linhas do CSV (sem o cabeçalho)
-- ---------------------------------------------------------------------
SELECT 'tm_competitions' AS tabela, COUNT(*) AS linhas, 65 AS esperado FROM stg.tm_competitions
UNION ALL SELECT 'tm_clubs', COUNT(*), 796 FROM stg.tm_clubs
UNION ALL SELECT 'tm_players', COUNT(*), 50149 FROM stg.tm_players
UNION ALL SELECT 'tm_games', COUNT(*), 88958 FROM stg.tm_games
UNION ALL SELECT 'tm_appearances', COUNT(*), 1894350 FROM stg.tm_appearances
UNION ALL SELECT 'tm_player_valuations', COUNT(*), 656301 FROM stg.tm_player_valuations
UNION ALL SELECT 'tm_transfers', COUNT(*), 175165 FROM stg.tm_transfers;

-- ---------------------------------------------------------------------
-- Conferência 2: as 4 ligas em 2015/16, contra o StatsBomb
-- Esperado: ES1 380 | 1.043, FR1 380 | 960, GB1 380 | 1.026,
--           IT1 380 | 979. Iguais ao StatsBomb, menos a Ligue 1: lá são
--           377 partidas e 949 gols (faltam 3 partidas na origem).
-- ---------------------------------------------------------------------
SELECT competition_id, COUNT(*) AS jogos, SUM(home_club_goals + away_club_goals) AS gols
FROM stg.tm_games
WHERE season = 2015 AND competition_id IN ('GB1', 'ES1', 'IT1', 'FR1')
GROUP BY competition_id
ORDER BY competition_id;

-- ---------------------------------------------------------------------
-- Conferência 3: Chelsea (club_id 631) na Premier League 2015/16
-- Esperado: 38 jogos, 59 pró e 53 contra (igual ao StatsBomb);
--           appearances: 521 linhas, 28 jogadores (igual ao lineup do
--           StatsBomb), 55 gols (os outros 4 são gols contra a favor)
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS jogos,
       SUM(CASE WHEN home_club_id = 631 THEN home_club_goals ELSE away_club_goals END) AS pro,
       SUM(CASE WHEN home_club_id = 631 THEN away_club_goals ELSE home_club_goals END) AS contra
FROM stg.tm_games
WHERE competition_id = 'GB1' AND season = 2015 AND 631 IN (home_club_id, away_club_id);

SELECT COUNT(*) AS linhas, COUNT(DISTINCT a.player_id) AS jogadores, SUM(a.goals) AS gols
FROM stg.tm_appearances a
JOIN stg.tm_games g ON g.game_id = a.game_id
WHERE g.competition_id = 'GB1' AND g.season = 2015 AND a.player_club_id = 631;

-- ---------------------------------------------------------------------
-- Conferência 4: contratações do Chelsea em 2016/17 (taxa x valor TM)
-- Esperado: Batshuayi 39,0 mi x 15 mi; Kanté 35,8 x 20; Alonso 23 x 9.
-- O David Luiz (PSG -> Chelsea) não tem nenhuma linha no transfers.csv
-- (pendência da D6.6). Atenção: o valor TM "na transferência" (9 mi do
-- Alonso) não é a última avaliação até 30/06/2016 da D6.6 (8 mi, em
-- 04/01/2016): o fato_valor_mercado usa a tm_player_valuations.
-- ---------------------------------------------------------------------
SELECT player_name, transfer_date, from_club_name, transfer_fee, market_value_in_eur
FROM stg.tm_transfers
WHERE to_club_id = 631 AND transfer_season = '16/17' AND transfer_fee > 0
ORDER BY transfer_fee DESC;
GO
