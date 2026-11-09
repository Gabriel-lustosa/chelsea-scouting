-- =====================================================================
-- Projeto: Chelsea 2015/16 — Scouting e Recrutamento
-- Arquivo: 01_sql/02_carga_statsbomb.sql
-- Objetivo: carregar os JSONs do StatsBomb (C:\dados\chelsea_scouting\
--           statsbomb) nas tabelas stg.sb_* com OPENROWSET + OPENJSON
--           (D7.1), sem conversão fora do SQL Server.
--
-- O arquivo é montado aula a aula, junto com a carga no SSMS:
--   [x] stg.sb_matches   Premier League (2_27.json)              Aula 5
--   [x] stg.sb_matches   La Liga, Serie A e Ligue 1 (laço)       Aula 6
--   [x] stg.sb_lineups   1.517 arquivos lineups\<match_id>.json  Aula 7
--   [x] stg.sb_events    1.517 arquivos events\<match_id>.json   Aula 8
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
--   * O OPENROWSET só aceita o caminho escrito direto (literal), não
--     variável. Para ler vários arquivos, só a LEITURA vai para SQL
--     dinâmico (sp_executesql devolve o arquivo no @json, parâmetro
--     OUTPUT); o OPENJSON com os caminhos fica em SQL normal, sem
--     precisar dobrar aspas.
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
-- stg.sb_matches: as 4 ligas de 2015/16, um arquivo por liga
-- (2 = Premier League, 7 = Ligue 1, 11 = La Liga, 12 = Serie A)
-- Conferido em 2026-11-06: 1.517 partidas e 3.997 gols (por liga, ver a
-- conferência no fim); Chelsea 59 pró e 53 contra em 38 jogos (igual ao
-- levantamento e ao Transfermarkt).
-- Técnicos do Chelsea: Mourinho 16 jogos (até 14/12), Steve Holland 1
-- (interino, 19/12) e Hiddink 21. O nickname do Hiddink vem NULL: nas
-- dimensões, usar COALESCE(nickname, name).
-- Partidas sem técnico registrado no JSON (colunas NULL): Ligue 1 29,
-- La Liga 3, Serie A 1.
-- ---------------------------------------------------------------------
TRUNCATE TABLE stg.sb_matches;

DECLARE @ligas TABLE (liga INT);
INSERT INTO @ligas VALUES (2), (11), (12), (7);

DECLARE @liga INT, @arquivo NVARCHAR(400), @sql NVARCHAR(MAX), @json VARCHAR(MAX), @linhas INT;

WHILE EXISTS (SELECT 1 FROM @ligas)
BEGIN
    SELECT TOP 1 @liga = liga FROM @ligas ORDER BY liga;
    SET @arquivo = N'C:\dados\chelsea_scouting\statsbomb\matches\' + CAST(@liga AS NVARCHAR(10)) + N'_27.json';

    -- leitura dinâmica: '' dentro do texto vira uma aspa no comando montado
    SET @sql = N'SELECT @json = CAST(BulkColumn AS varchar(max)) FROM OPENROWSET(BULK ''' + @arquivo + N''', SINGLE_BLOB) AS arq;';
    EXEC sp_executesql @sql, N'@json VARCHAR(MAX) OUTPUT', @json = @json OUTPUT;

    INSERT INTO stg.sb_matches
    SELECT m.*
    FROM OPENJSON(@json)
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
    SET @linhas = @@ROWCOUNT;   -- salvar logo depois do INSERT

    PRINT CONCAT('Liga ', @liga, ': ', @linhas, ' partidas gravadas');
    DELETE FROM @ligas WHERE liga = @liga;
END;
GO

-- ---------------------------------------------------------------------
-- Conferência: partidas e gols por liga, e gols do Chelsea
-- Esperado: PL 380 | 1026, Ligue 1 377 | 949, La Liga 380 | 1043,
--           Serie A 380 | 979 (total 1.517 | 3.997); Chelsea 59 | 53
-- ---------------------------------------------------------------------
SELECT competition_id, competition_name,
       COUNT(*)                     AS partidas,
       SUM(home_score + away_score) AS gols
FROM stg.sb_matches
GROUP BY competition_id, competition_name
ORDER BY competition_id;

SELECT SUM(CASE WHEN home_team_name = 'Chelsea' THEN home_score
                WHEN away_team_name = 'Chelsea' THEN away_score END) AS chelsea_pro,
       SUM(CASE WHEN home_team_name = 'Chelsea' THEN away_score
                WHEN away_team_name = 'Chelsea' THEN home_score END) AS chelsea_contra
FROM stg.sb_matches;
GO

-- ---------------------------------------------------------------------
-- stg.sb_lineups: um arquivo por partida (lineups\<match_id>.json)
-- O arquivo tem 3 listas, uma dentro da outra: times > lineup
-- (jogadores) > positions (trechos em cada posição). Cada nível é aberto
-- com OPENJSON + CROSS APPLY; a lista de dentro passa como texto pelo
-- AS JSON (coluna NVARCHAR(MAX)).
--   * position_seq: o OPENJSON sem WITH devolve key/value/type; numa
--     lista o key é a posição do item a partir de 0, daí o + 1. O value
--     é aberto de novo com WITH para pegar os campos.
--   * Reservas que não entraram têm positions = [] e somem sozinhos:
--     CROSS APPLY numa lista vazia não gera linha (OUTER APPLY manteria).
--   * A lista de partidas vem da própria stg.sb_matches, de match_id em
--     match_id (MIN ... WHERE match_id > @match_id); NULL = acabou.
-- Conferido em 2026-11-07 (~20 s): 1.517 arquivos, 56.884 linhas, 2.176
-- jogadores, position_seq de 1 a 8; Chelsea 635 linhas e 28 jogadores.
-- Limitações da origem (anotadas para o fato_atuacao):
--   * Expulsão quase nunca encerra o trecho: no Chelsea x Swansea
--     (3754078) o Courtois expulso vira "Center Attacking Midfield" aos
--     53:40 até o apito. Só 30 linhas terminam com Red Card, Second
--     Yellow ou Player Off (Permanent). Minutos só pelo lineup dão
--     tempo a mais ao expulso: cortar com os cartões dos eventos.
--   * Escalação incompleta: Deportivo x Sporting Gijón (3825596, Gijón
--     com 8 titulares) e Liverpool x Swansea (3754047, Swansea com 1).
--     33.361 titulares em vez de 33.374.
--   * 4 linhas sem país (country_name NULL).
-- ---------------------------------------------------------------------
TRUNCATE TABLE stg.sb_lineups;

DECLARE @match_id INT = 0, @sql NVARCHAR(MAX), @json VARCHAR(MAX), @arquivos INT = 0;

WHILE 1 = 1
BEGIN
    SELECT @match_id = MIN(match_id) FROM stg.sb_matches WHERE match_id > @match_id;
    IF @match_id IS NULL BREAK;

    SET @sql = N'SELECT @json = CAST(BulkColumn AS varchar(max)) FROM OPENROWSET(BULK ''C:\dados\chelsea_scouting\statsbomb\lineups\'
             + CAST(@match_id AS NVARCHAR(10)) + N'.json'', SINGLE_BLOB) AS arq;';
    EXEC sp_executesql @sql, N'@json VARCHAR(MAX) OUTPUT', @json = @json OUTPUT;

    INSERT INTO stg.sb_lineups
    SELECT @match_id, t.team_id, t.team_name,
           j.player_id, j.player_name, j.player_nickname, j.jersey_number, j.country_name,
           CAST(p.[key] AS INT) + 1,
           pos.position_id, pos.position, pos.from_time, pos.to_time,
           pos.from_period, pos.to_period, pos.start_reason, pos.end_reason
    FROM OPENJSON(@json)
    WITH (
        team_id    INT           '$.team_id',
        team_name  NVARCHAR(100) '$.team_name',
        lineup     NVARCHAR(MAX) '$.lineup' AS JSON
    ) AS t
    CROSS APPLY OPENJSON(t.lineup)
    WITH (
        player_id        INT           '$.player_id',
        player_name      NVARCHAR(150) '$.player_name',
        player_nickname  NVARCHAR(100) '$.player_nickname',
        jersey_number    INT           '$.jersey_number',
        country_name     NVARCHAR(100) '$.country.name',
        positions        NVARCHAR(MAX) '$.positions' AS JSON
    ) AS j
    CROSS APPLY OPENJSON(j.positions) AS p
    CROSS APPLY OPENJSON(p.value)
    WITH (
        position_id   INT           '$.position_id',
        position      NVARCHAR(50)  '$.position',
        from_time     VARCHAR(10)   '$.from',
        to_time       VARCHAR(10)   '$.to',
        from_period   INT           '$.from_period',
        to_period     INT           '$.to_period',
        start_reason  NVARCHAR(100) '$.start_reason',
        end_reason    NVARCHAR(100) '$.end_reason'
    ) AS pos;

    SET @arquivos += 1;
END;

PRINT CONCAT(@arquivos, ' arquivos lidos');
GO

-- ---------------------------------------------------------------------
-- Conferência: linhas, partidas e jogadores por liga, e o Chelsea
-- Esperado: La Liga 13.609 | 380 | 539, Ligue 1 15.224 | 377 | 574,
--           Premier League 12.717 | 380 | 550, Serie A 15.334 | 380 | 551
--           (total 56.884 linhas); Chelsea 635 linhas e 28 jogadores
-- ---------------------------------------------------------------------
SELECT m.competition_name,
       COUNT(*)                    AS linhas,
       COUNT(DISTINCT l.match_id)  AS partidas,
       COUNT(DISTINCT l.player_id) AS jogadores
FROM stg.sb_lineups l
JOIN stg.sb_matches m ON m.match_id = l.match_id
GROUP BY m.competition_name
ORDER BY m.competition_name;

SELECT COUNT(*) AS linhas_chelsea, COUNT(DISTINCT player_id) AS jogadores_chelsea
FROM stg.sb_lineups
WHERE team_name = 'Chelsea';
GO

-- ---------------------------------------------------------------------
-- stg.sb_events: um arquivo por partida (events\<match_id>.json), uma
-- linha por lance. Mesmo laço das escalações; o OPENJSON tem um nível só.
--   * '$.location[0]' e '[1]': a lista [x, y] do JSON, item a item
--     (começa no 0).
--   * O WITH lê 42 campos e a tabela tem 39 colunas: o aerial_won vem de
--     4 lugares (pass, shot, clearance, miscontrol) e o card de 2
--     (foul_committed, bad_behaviour, D8). O COALESCE pega o primeiro que
--     não for NULL; cada lance tem no máximo um deles. Por isso o SELECT
--     lista as colunas na ordem da tabela, em vez de e.*.
--   * xG lido como FLOAT e convertido para DECIMAL(11,10) (D9): 7 chutes
--     vêm em notação científica (1.8E-4), que o DECIMAL não lê, e 18.722
--     dos 37.888 têm 9 ou 10 casas. Testado: 0 diferenças do JSON.
--   * Cada INSERT grava sozinho: se o laço parar no meio, o que entrou
--     antes fica. O TRUNCATE do começo deixa rodar de novo do zero.
--   * RAISERROR(..., 0, ...) WITH NOWAIT: nível 0 não é erro; mostra o
--     progresso na hora (o PRINT só aparece no fim do lote).
-- Conferido em 2026-11-08 (~4 min): 1.517 partidas, 5.321.459 eventos;
-- gols dos eventos (chute Goal + Own Goal For) = placar da sb_matches em
-- todas as partidas; Chelsea 59 pró e 53 contra, xG 1,41 e xG contra
-- 1,26 por jogo (igual ao levantamento); 196 vermelhos, 217 segundos
-- amarelos e 6.682 amarelos; vermelho do Courtois aos 51:37 (3754078).
-- ---------------------------------------------------------------------
TRUNCATE TABLE stg.sb_events;

DECLARE @match_id INT = 0, @sql NVARCHAR(MAX), @json VARCHAR(MAX), @arquivos INT = 0;

WHILE 1 = 1
BEGIN
    SELECT @match_id = MIN(match_id) FROM stg.sb_matches WHERE match_id > @match_id;
    IF @match_id IS NULL BREAK;

    SET @sql = N'SELECT @json = CAST(BulkColumn AS varchar(max)) FROM OPENROWSET(BULK ''C:\dados\chelsea_scouting\statsbomb\events\'
             + CAST(@match_id AS NVARCHAR(10)) + N'.json'', SINGLE_BLOB) AS arq;';
    EXEC sp_executesql @sql, N'@json VARCHAR(MAX) OUTPUT', @json = @json OUTPUT;

    INSERT INTO stg.sb_events
    SELECT @match_id, e.event_index, e.id, e.period, e.[timestamp], e.minute, e.second,
           e.type_id, e.type_name, e.possession, e.possession_team_id, e.play_pattern,
           e.team_id, e.player_id, e.position_id, e.location_x, e.location_y,
           e.under_pressure, e.counterpress,
           e.pass_end_location_x, e.pass_end_location_y, e.pass_outcome, e.pass_type,
           e.pass_height, e.pass_cross, e.pass_shot_assist, e.pass_goal_assist,
           e.carry_end_location_x, e.carry_end_location_y,
           e.dribble_outcome, e.duel_type, e.duel_outcome, e.interception_outcome,
           e.ball_recovery_recovery_failure,
           COALESCE(e.pass_aerial_won, e.shot_aerial_won, e.clearance_aerial_won, e.miscontrol_aerial_won),
           CAST(e.shot_statsbomb_xg AS DECIMAL(11,10)), e.shot_type, e.shot_outcome,
           COALESCE(e.foul_committed_card, e.bad_behaviour_card)
    FROM OPENJSON(@json)
    WITH (
        event_index                     INT              '$.index',
        id                              UNIQUEIDENTIFIER '$.id',
        period                          INT              '$.period',
        [timestamp]                     TIME(3)          '$.timestamp',
        minute                          INT              '$.minute',
        second                          INT              '$.second',
        type_id                         INT              '$.type.id',
        type_name                       NVARCHAR(50)     '$.type.name',
        possession                      INT              '$.possession',
        possession_team_id              INT              '$.possession_team.id',
        play_pattern                    NVARCHAR(50)     '$.play_pattern.name',
        team_id                         INT              '$.team.id',
        player_id                       INT              '$.player.id',
        position_id                     INT              '$.position.id',
        location_x                      DECIMAL(5,2)     '$.location[0]',
        location_y                      DECIMAL(5,2)     '$.location[1]',
        under_pressure                  BIT              '$.under_pressure',
        counterpress                    BIT              '$.counterpress',
        pass_end_location_x             DECIMAL(5,2)     '$.pass.end_location[0]',
        pass_end_location_y             DECIMAL(5,2)     '$.pass.end_location[1]',
        pass_outcome                    NVARCHAR(50)     '$.pass.outcome.name',
        pass_type                       NVARCHAR(50)     '$.pass.type.name',
        pass_height                     NVARCHAR(50)     '$.pass.height.name',
        pass_cross                      BIT              '$.pass.cross',
        pass_shot_assist                BIT              '$.pass.shot_assist',
        pass_goal_assist                BIT              '$.pass.goal_assist',
        carry_end_location_x            DECIMAL(5,2)     '$.carry.end_location[0]',
        carry_end_location_y            DECIMAL(5,2)     '$.carry.end_location[1]',
        dribble_outcome                 NVARCHAR(50)     '$.dribble.outcome.name',
        duel_type                       NVARCHAR(50)     '$.duel.type.name',
        duel_outcome                    NVARCHAR(50)     '$.duel.outcome.name',
        interception_outcome            NVARCHAR(50)     '$.interception.outcome.name',
        ball_recovery_recovery_failure  BIT              '$.ball_recovery.recovery_failure',
        pass_aerial_won                 BIT              '$.pass.aerial_won',
        shot_aerial_won                 BIT              '$.shot.aerial_won',
        clearance_aerial_won            BIT              '$.clearance.aerial_won',
        miscontrol_aerial_won           BIT              '$.miscontrol.aerial_won',
        shot_statsbomb_xg               FLOAT            '$.shot.statsbomb_xg',   -- D9
        shot_type                       NVARCHAR(50)     '$.shot.type.name',
        shot_outcome                    NVARCHAR(50)     '$.shot.outcome.name',
        foul_committed_card             NVARCHAR(50)     '$.foul_committed.card.name',
        bad_behaviour_card              NVARCHAR(50)     '$.bad_behaviour.card.name'
    ) AS e;

    SET @arquivos += 1;
    IF @arquivos % 100 = 0 RAISERROR('%d arquivos', 0, 1, @arquivos) WITH NOWAIT;
END;

PRINT CONCAT(@arquivos, ' arquivos lidos');
GO

-- ---------------------------------------------------------------------
-- Conferência: eventos, partidas, gols e xG por liga; Chelsea; cartões
-- Esperado: La Liga 1.295.354 | 380 | 1.043, Ligue 1 1.358.593 | 377 |
--           949, Premier League 1.313.773 | 380 | 1.026, Serie A
--           1.353.739 | 380 | 979 (total 5.321.459; 37.888 chutes);
--           0 partidas com gols diferentes do placar; Chelsea 59 | 53,
--           xG 1,41 | 1,26 por jogo; Red Card 196, Second Yellow 217,
--           Yellow Card 6.682
-- ---------------------------------------------------------------------
SELECT m.competition_name,
       COUNT(*)                                     AS eventos,
       COUNT(DISTINCT e.match_id)                   AS partidas,
       SUM(CASE WHEN e.shot_outcome = 'Goal' OR e.type_name = 'Own Goal For'
                THEN 1 ELSE 0 END)                  AS gols,
       COUNT(e.shot_statsbomb_xg)                   AS chutes,
       SUM(e.shot_statsbomb_xg)                     AS xg
FROM stg.sb_events e
JOIN stg.sb_matches m ON m.match_id = e.match_id
GROUP BY m.competition_name
ORDER BY m.competition_name;

SELECT COUNT(*) AS partidas_com_gols_diferentes_do_placar
FROM stg.sb_matches m
CROSS APPLY (SELECT SUM(CASE WHEN e.shot_outcome = 'Goal' OR e.type_name = 'Own Goal For'
                             THEN 1 ELSE 0 END) AS gols
             FROM stg.sb_events e WHERE e.match_id = m.match_id) g
WHERE ISNULL(g.gols, -1) <> m.home_score + m.away_score;

SELECT SUM(CASE WHEN e.team_id = 33 AND (e.shot_outcome = 'Goal' OR e.type_name = 'Own Goal For') THEN 1 ELSE 0 END) AS chelsea_pro,
       SUM(CASE WHEN e.team_id <> 33 AND (e.shot_outcome = 'Goal' OR e.type_name = 'Own Goal For') THEN 1 ELSE 0 END) AS chelsea_contra,
       CAST(SUM(CASE WHEN e.team_id = 33 THEN e.shot_statsbomb_xg END) / 38 AS DECIMAL(5,2))  AS xg_por_jogo,
       CAST(SUM(CASE WHEN e.team_id <> 33 THEN e.shot_statsbomb_xg END) / 38 AS DECIMAL(5,2)) AS xg_contra_por_jogo
FROM stg.sb_events e
JOIN stg.sb_matches m ON m.match_id = e.match_id
WHERE 33 IN (m.home_team_id, m.away_team_id);

SELECT card, COUNT(*) AS cartoes
FROM stg.sb_events
WHERE card IS NOT NULL
GROUP BY card
ORDER BY card;
GO
