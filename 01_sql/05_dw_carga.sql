-- =====================================================================
-- Projeto: Chelsea 2015/16 — Scouting e Recrutamento
-- Arquivo: 01_sql/05_dw_carga.sql
-- Objetivo: carregar as tabelas do schema dw a partir da staging
--           (TRUNCATE + INSERT, D10.4 e D11.1). As tabelas são criadas
--           pelo 04_dw_tabelas.sql.
--
-- O arquivo é montado aula a aula, junto com o DW no SSMS:
--   Bloco 1 — StatsBomb (D10.2) — completo
--   [x] dw.dim_data        calendário gerado, sem origem        Aula 10
--   [x] dw.dim_liga        65 competições TM + 4 faltantes      Aula 11
--   [x] dw.dim_posicao     25 posições, 9 grupos, 4 setores     Aula 12
--   [x] dw.dim_time        80 times SB ligados ao TM por votação Aula 13
--   [x] dw.dim_partida     1.517 partidas SB x 2 lados (D15)    Aula 14
--   [x] dw.dim_jogador     2.176 jogadores SB, atributos 15/16  Aula 15
--   [x] stg.sb_trechos     56.884 trechos, minutos certos (D17) Aula 16
--   [x] dw.dim_partida     posse por partida × time (D17.4)     Aula 17
--   [x] dw.fato_desempenho 54.415 jogador × partida × posição   Aula 17
--   [x] dw.dim_jogador     UPDATE da posição principal (D17.5)  Aula 18
--   Bloco 2 — Transfermarkt
--   [x] stg.ligacao_jogadores 2.279 pares, 5 regras (D18)       Aula 19
--   [x] dw.dim_jogador     tm_player_id dos 2.176 (D18.4)       Aula 19
--   [ ] dw.dim_time        clubes só do TM (sb_team_id NULL)
--   [ ] dw.dim_partida     jogos só do TM (sb_match_id NULL)
--   [x] dw.dim_jogador     5 do Chelsea 14/15 + atributos TM    Aula 20
--   [ ] dw.fato_valor_mercado, dw.fato_atuacao, dw.fato_transferencia
--
-- Como funciona:
--   * TRUNCATE antes de cada INSERT: o script pode rodar de novo sem
--     duplicar. Funciona porque não há FK declarada (D11.2).
--   * Datas escritas como 'AAAAMMDD' ('20140101'): esse formato é lido
--     igual em qualquer idioma da sessão (o SET LANGUAGE 'Brazilian'
--     muda a ordem de dia e mês em outros formatos).
--   * SET QUOTED_IDENTIFIER ON: gravar numa tabela com índice filtrado
--     (dim_time) exige essa opção. O SSMS já liga; o sqlcmd deixa
--     desligada.
--
-- Rodar com (depois do 04_dw_tabelas.sql):
--   sqlcmd -S localhost -E -C -f 65001 -i 01_sql\05_dw_carga.sql
-- =====================================================================

USE chelsea_scouting;
GO

SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;

-- ---------------------------------------------------------------------
-- dw.dim_data: 01/01/2014 a 31/12/2026 (D11.3), colunas da D11.4
-- * GENERATE_SERIES devolve os números 0, 1, 2... (coluna value); somando
--   cada um a 01/01/2014 sai um dia por linha. Substitui a CTE recursiva
--   do Olist, sem precisar de MAXRECURSION.
-- * SET LANGUAGE 'Brazilian': DATENAME devolve 'Janeiro', 'Segunda-Feira'.
-- * SET DATEFIRST 7: a semana começa no domingo (dia_semana 1 = domingo).
-- * A temporada começa em 1º de julho: de julho em diante, no próprio
--   ano; antes, no ano anterior.
-- Conferido em 2026-11-09: igual ao gabarito gerado do zero (EXCEPT 0/0).
-- ---------------------------------------------------------------------
SET LANGUAGE 'Brazilian';
SET DATEFIRST 7;

TRUNCATE TABLE dw.dim_data;

WITH calendario AS (
    SELECT DATEADD(DAY, value, CAST('20140101' AS DATE)) AS data
    FROM GENERATE_SERIES(0, DATEDIFF(DAY, '20140101', '20261231'))
),
base AS (
    SELECT data,
           CASE WHEN MONTH(data) >= 7 THEN YEAR(data) ELSE YEAR(data) - 1 END AS ano_inicio
    FROM calendario
)
INSERT INTO dw.dim_data (sk_data, data, ano, trimestre, mes, mes_nome, dia, dia_semana,
                         dia_semana_nome, eh_fim_semana, temporada, temporada_ano_inicio,
                         periodo_cenario)
SELECT CAST(CONVERT(CHAR(8), data, 112) AS INT),             -- 112 = formato AAAAMMDD
       data,
       YEAR(data),
       DATEPART(QUARTER, data),
       MONTH(data),
       DATENAME(MONTH, data),
       DAY(data),
       DATEPART(WEEKDAY, data),
       DATENAME(WEEKDAY, data),
       CASE WHEN DATEPART(WEEKDAY, data) IN (1, 7) THEN 1 ELSE 0 END,
       CONCAT(ano_inicio, '/', RIGHT(ano_inicio + 1, 2)),     -- 2015 -> '2015/16'
       ano_inicio,
       CASE WHEN data <= '20160630' THEN N'Até a janela de 2016' ELSE N'Depois' END
FROM base;

RAISERROR('dw.dim_data ok', 0, 1) WITH NOWAIT;
GO

-- ---------------------------------------------------------------------
-- dw.dim_liga: 69 competições (D12)
-- * As 4 que faltam no competitions.csv entram por VALUES: CGB (EFL Cup,
--   2.348 atuações), POCP (Taça da Liga, 9.769), KLUB (Mundial de Clubes,
--   1.808), UKRS (Supercopa da Ucrânia, 275). Fica fora o COL1 (200 jogos
--   da Colômbia em 2025, sem nenhuma atuação).
-- * Nome por regra: STRING_SPLIT(texto, '-', 1) quebra em pedaços com a
--   posição (ordinal); STRING_AGG cola de volta com a 1ª letra maiúscula.
--   Exceções escritas no CASE.
-- * Tipo: o CASE fica com a 1ª condição verdadeira; por isso a Supercopa
--   da UEFA vira 'Supercopa' antes do LIKE 'uefa%'. 'Outra' = rede de
--   segurança (esperado 0).
-- * TRUNCATE reinicia o IDENTITY; ORDER BY faz o sk_liga seguir o código
--   do Transfermarkt (A1 = 1).
-- Conferido em 2026-11-09: igual ao gabarito (EXCEPT 0/0), 0 atuações
-- órfãs.
-- ---------------------------------------------------------------------
TRUNCATE TABLE dw.dim_liga;

WITH competicoes AS (
    SELECT competition_id, name, sub_type, type, country_name, confederation
    FROM stg.tm_competitions
    UNION ALL
    SELECT competition_id, name, sub_type, type, country_name, confederation
    FROM (VALUES
        (N'CGB',  N'efl-cup',             N'league_cup',         N'domestic_cup',      N'England',  N'europa'),
        (N'POCP', N'taca-da-liga',        N'league_cup',         N'domestic_cup',      N'Portugal', N'europa'),
        (N'KLUB', N'fifa-club-world-cup', N'club_world_cup',     N'international_cup', NULL,        N'fifa'),
        (N'UKRS', N'ukrainian-super-cup', N'domestic_super_cup', N'other',             N'Ukraine',  N'europa')
    ) AS faltantes (competition_id, name, sub_type, type, country_name, confederation)
),
nomes AS (
    SELECT c.*,
           (SELECT STRING_AGG(UPPER(LEFT(p.value, 1)) + SUBSTRING(p.value, 2, 100), ' ')
                   WITHIN GROUP (ORDER BY p.ordinal)
            FROM STRING_SPLIT(c.name, '-', 1) AS p) AS nome_regra
    FROM competicoes c
)
INSERT INTO dw.dim_liga (tm_competition_id, sb_competition_id, nome, tipo, pais,
                         confederacao, eh_liga_do_estudo)
SELECT competition_id,
       CASE competition_id WHEN 'GB1' THEN 2 WHEN 'ES1' THEN 11
                           WHEN 'IT1' THEN 12 WHEN 'FR1' THEN 7 END,
       CASE competition_id
            WHEN 'GB1'  THEN N'Premier League'
            WHEN 'ES1'  THEN N'La Liga'
            WHEN 'IT1'  THEN N'Serie A'
            WHEN 'FR1'  THEN N'Ligue 1'
            WHEN 'CGB'  THEN N'EFL Cup'
            WHEN 'POCP' THEN N'Taça da Liga'
            WHEN 'KLUB' THEN N'FIFA Club World Cup'
            WHEN 'FAC'  THEN N'FA Cup'
            WHEN 'AFAC' THEN N'AFC Asian Cup'
            WHEN 'AFCN' THEN N'Africa Cup of Nations'
            WHEN 'CDR'  THEN N'Copa del Rey'
            ELSE REPLACE(REPLACE(nome_regra, N'Uefa', N'UEFA'), N'Dfb', N'DFB')
       END,
       CASE WHEN competition_id = 'KLUB'                              THEN N'Mundial de Clubes'
            WHEN type = 'domestic_league'                             THEN N'Liga nacional'
            WHEN type = 'domestic_cup'                                THEN N'Copa nacional'
            WHEN sub_type IN ('domestic_super_cup', 'uefa_super_cup') THEN N'Supercopa'
            WHEN type = 'national_team_competition'                   THEN N'Seleções'
            WHEN sub_type = 'play_off'                                THEN N'Playoff'
            WHEN sub_type LIKE 'uefa%'                                THEN N'Competição europeia'
            ELSE N'Outra'
       END,
       country_name,
       CASE confederation WHEN 'europa'  THEN N'Europa'
                          WHEN 'amerika' THEN N'Américas'
                          WHEN 'asien'   THEN N'Ásia'
                          WHEN 'afrika'  THEN N'África'
                          WHEN 'fifa'    THEN N'FIFA' END,
       CASE WHEN competition_id IN ('GB1', 'ES1', 'IT1', 'FR1') THEN 1 ELSE 0 END
FROM nomes
ORDER BY competition_id;

RAISERROR('dw.dim_liga ok', 0, 1) WITH NOWAIT;
GO

-- ---------------------------------------------------------------------
-- dw.dim_posicao: 25 posições do StatsBomb (D13)
-- * A staging não tem tabela de posições: as 25 ficam escritas aqui, em
--   duas listas VALUES. A 1ª dá o grupo de cada posição; a 2ª dá o setor,
--   a ordem e o escopo de cada grupo. Com o setor escrito uma vez por
--   grupo, nenhum grupo cai em dois setores.
-- * Nome de grupo digitado errado numa das listas: o JOIN não acha o par
--   e a posição some (a conferência pega: menos de 25 linhas).
-- * AS p (...): um VALUES solto não tem nome de coluna; esta parte dá.
-- * lado: toda posição de lado começa com 'Right ' ou 'Left '.
-- * ORDER BY: o sk_posicao sai igual ao sb_position_id.
-- Conferido em 2026-11-09: igual ao gabarito (EXCEPT 0/0), 0 trechos das
-- escalações sem posição.
-- ---------------------------------------------------------------------
TRUNCATE TABLE dw.dim_posicao;

WITH posicoes AS (
    SELECT *
    FROM (VALUES
        ( 1, N'Goalkeeper',                N'Goleiro',                N'GK',  N'Goleiro'),
        ( 2, N'Right Back',                N'Lateral direito',        N'RB',  N'Lateral'),
        ( 3, N'Right Center Back',         N'Zagueiro direito',       N'RCB', N'Zagueiro'),
        ( 4, N'Center Back',               N'Zagueiro central',       N'CB',  N'Zagueiro'),
        ( 5, N'Left Center Back',          N'Zagueiro esquerdo',      N'LCB', N'Zagueiro'),
        ( 6, N'Left Back',                 N'Lateral esquerdo',       N'LB',  N'Lateral'),
        ( 7, N'Right Wing Back',           N'Ala direito',            N'RWB', N'Lateral'),
        ( 8, N'Left Wing Back',            N'Ala esquerdo',           N'LWB', N'Lateral'),
        ( 9, N'Right Defensive Midfield',  N'Volante direito',        N'RDM', N'Volante'),
        (10, N'Center Defensive Midfield', N'Volante central',        N'CDM', N'Volante'),
        (11, N'Left Defensive Midfield',   N'Volante esquerdo',       N'LDM', N'Volante'),
        (12, N'Right Midfield',            N'Meia aberto direito',    N'RM',  N'Meia aberto'),
        (13, N'Right Center Midfield',     N'Meia central direito',   N'RCM', N'Meia central'),
        (14, N'Center Midfield',           N'Meia central',           N'CM',  N'Meia central'),
        (15, N'Left Center Midfield',      N'Meia central esquerdo',  N'LCM', N'Meia central'),
        (16, N'Left Midfield',             N'Meia aberto esquerdo',   N'LM',  N'Meia aberto'),
        (17, N'Right Wing',                N'Ponta direita',          N'RW',  N'Ponta'),
        (18, N'Right Attacking Midfield',  N'Meia ofensivo direito',  N'RAM', N'Meia ofensivo'),
        (19, N'Center Attacking Midfield', N'Meia ofensivo central',  N'CAM', N'Meia ofensivo'),
        (20, N'Left Attacking Midfield',   N'Meia ofensivo esquerdo', N'LAM', N'Meia ofensivo'),
        (21, N'Left Wing',                 N'Ponta esquerda',         N'LW',  N'Ponta'),
        (22, N'Right Center Forward',      N'Atacante direito',       N'RCF', N'Atacante'),
        (23, N'Center Forward',            N'Centroavante',           N'CF',  N'Atacante'),
        (24, N'Left Center Forward',       N'Atacante esquerdo',      N'LCF', N'Atacante'),
        (25, N'Secondary Striker',         N'Segundo atacante',       N'SS',  N'Atacante')
    ) AS p (sb_position_id, posicao, posicao_pt, sigla, grupo)
),
grupos AS (
    SELECT *
    FROM (VALUES
        (N'Goleiro',       N'Goleiro', 1, 1, 0),
        (N'Zagueiro',      N'Defesa',  2, 2, 1),
        (N'Lateral',       N'Defesa',  3, 2, 1),
        (N'Volante',       N'Meio',    4, 3, 1),
        (N'Meia central',  N'Meio',    5, 3, 0),
        (N'Meia aberto',   N'Meio',    6, 3, 0),
        (N'Meia ofensivo', N'Meio',    7, 3, 0),
        (N'Ponta',         N'Ataque',  8, 4, 0),
        (N'Atacante',      N'Ataque',  9, 4, 0)
    ) AS g (grupo, setor, ordem_grupo, ordem_setor, eh_escopo)
)
INSERT INTO dw.dim_posicao (sb_position_id, posicao, posicao_pt, sigla, lado, grupo, setor,
                            eh_escopo, ordem_grupo, ordem_setor)
SELECT p.sb_position_id, p.posicao, p.posicao_pt, p.sigla,
       CASE WHEN p.posicao LIKE N'Right %' THEN N'Direito'
            WHEN p.posicao LIKE N'Left %'  THEN N'Esquerdo'
            ELSE N'Centro' END,
       p.grupo, g.setor, g.eh_escopo, g.ordem_grupo, g.ordem_setor
FROM posicoes p
JOIN grupos g ON g.grupo = p.grupo
ORDER BY p.sb_position_id;

RAISERROR('dw.dim_posicao ok', 0, 1) WITH NOWAIT;
GO

-- ---------------------------------------------------------------------
-- dw.dim_time: os 80 times do StatsBomb ligados ao Transfermarkt (D14)
-- * Ligação pelas partidas: cada partida SB é cruzada com os jogos TM de
--   mesma liga, data e placar. Em 297 partidas há mais de um jogo
--   possível, então cada par vira voto e o clube TM mais votado é o par
--   do time SB (80/80, vencedor com >= 37 votos, 2º com <= 5).
-- * A dim_liga traduz a liga SB (2) para a TM ('GB1') e dá país e nome.
-- * UNION na CTE 1 tira as repetições (uma linha por time); UNION ALL na
--   CTE 3 mantém todos os votos.
-- * ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...) numera dentro de
--   cada grupo: na CTE 4 pega o mais votado; na CTE 6, o último jogo.
-- * Posição final = a do TM depois do último jogo do clube na liga (pelo
--   StatsBomb não dá: faltam 3 partidas da Ligue 1).
-- Conferido em 2026-11-09: igual ao gabarito (EXCEPT 0/0).
-- ---------------------------------------------------------------------
TRUNCATE TABLE dw.dim_time;

WITH sb_times AS (          -- 1. os 80 times do StatsBomb, com a liga
    SELECT competition_id, home_team_id AS sb_team_id, home_team_name AS nome FROM stg.sb_matches
    UNION
    SELECT competition_id, away_team_id, away_team_name FROM stg.sb_matches
),
pares AS (                  -- 2. cada partida SB com os jogos TM de mesma liga, data e placar
    SELECT m.home_team_id, m.away_team_id, g.home_club_id, g.away_club_id
    FROM stg.sb_matches m
    JOIN dw.dim_liga l  ON l.sb_competition_id = m.competition_id
    JOIN stg.tm_games g ON g.competition_id = l.tm_competition_id
                       AND g.season = 2015
                       AND g.date = m.match_date
                       AND g.home_club_goals = m.home_score
                       AND g.away_club_goals = m.away_score
),
votos AS (                  -- 3. cada par vira 2 votos: mandante com mandante, visitante com visitante
    SELECT home_team_id AS sb_team_id, home_club_id AS tm_club_id FROM pares
    UNION ALL
    SELECT away_team_id, away_club_id FROM pares
),
ranking AS (                -- 4. conta os votos; lugar 1 = clube TM mais votado para cada time SB
    SELECT sb_team_id, tm_club_id, COUNT(*) AS votos,
           ROW_NUMBER() OVER (PARTITION BY sb_team_id ORDER BY COUNT(*) DESC) AS lugar
    FROM votos
    GROUP BY sb_team_id, tm_club_id
),
jogos_tm AS (               -- 5. posição de cada clube depois de cada jogo da liga (TM)
    SELECT home_club_id AS tm_club_id, date, home_club_position AS posicao
    FROM stg.tm_games WHERE season = 2015 AND competition_id IN ('GB1', 'ES1', 'IT1', 'FR1')
    UNION ALL
    SELECT away_club_id, date, away_club_position
    FROM stg.tm_games WHERE season = 2015 AND competition_id IN ('GB1', 'ES1', 'IT1', 'FR1')
),
posicao_final AS (          -- 6. fica só o último jogo de cada clube
    SELECT tm_club_id, posicao,
           ROW_NUMBER() OVER (PARTITION BY tm_club_id ORDER BY date DESC) AS ultimo
    FROM jogos_tm
)
INSERT INTO dw.dim_time (sb_team_id, tm_club_id, nome, nome_tm, pais, liga_2015_16,
                         posicao_2015_16, eh_time_do_estudo)
SELECT t.sb_team_id, r.tm_club_id, t.nome, c.name, l.pais, l.nome, p.posicao, 1
FROM sb_times t
JOIN dw.dim_liga l        ON l.sb_competition_id = t.competition_id
JOIN ranking r            ON r.sb_team_id = t.sb_team_id AND r.lugar = 1
LEFT JOIN stg.tm_clubs c  ON c.club_id = r.tm_club_id
LEFT JOIN posicao_final p ON p.tm_club_id = r.tm_club_id AND p.ultimo = 1
ORDER BY t.sb_team_id;

RAISERROR('dw.dim_time ok', 0, 1) WITH NOWAIT;
GO

-- ---------------------------------------------------------------------
-- dw.dim_partida: 1.517 partidas do StatsBomb × 2 lados = 3.034 (D15)
-- * Ligação SB × TM pela D6.4: data + mandante + visitante, com os
--   clubes TM vindos da dim_time (1.517/1.517, placar igual em todas).
-- * A dim_time entra duas vezes: tc (time da casa) e tf (time de fora).
-- * O UNION ALL abre cada partida em 2 linhas. Os nomes das colunas vêm
--   só da 1ª metade; na 2ª vale a ordem, com casa e fora trocados.
-- * Técnico, formação e gols do Transfermarkt (D15.3).
-- * ORDER BY: o sk_partida segue a data; dentro da partida, 'Casa' vem
--   antes de 'Fora'.
-- Conferido em 2026-11-09: igual ao gabarito (EXCEPT 0/0).
-- ---------------------------------------------------------------------
TRUNCATE TABLE dw.dim_partida;

WITH partidas AS (          -- 1. cada partida SB com o seu jogo TM (D6.4: data + mandante + visitante)
    SELECT m.match_id, m.match_week, m.home_team_id, m.away_team_id,
           g.game_id, g.competition_id, g.season, g.date,
           g.home_club_id, g.away_club_id, g.home_club_goals, g.away_club_goals,
           g.home_club_manager_name, g.away_club_manager_name,
           g.home_club_formation, g.away_club_formation,
           tc.nome AS nome_casa, tf.nome AS nome_fora,
           tc.posicao_2015_16 AS posicao_casa, tf.posicao_2015_16 AS posicao_fora
    FROM stg.sb_matches m
    JOIN dw.dim_time tc ON tc.sb_team_id = m.home_team_id
    JOIN dw.dim_time tf ON tf.sb_team_id = m.away_team_id
    JOIN stg.tm_games g ON g.home_club_id = tc.tm_club_id
                       AND g.away_club_id = tf.tm_club_id
                       AND g.date = m.match_date
),
lados AS (                  -- 2. cada partida vira 2 linhas: o lado do mandante e o do visitante
    SELECT match_id, home_team_id AS sb_team_id, game_id, home_club_id AS tm_club_id,
           competition_id, season, date, match_week, nome_casa, nome_fora,
           home_club_goals, away_club_goals,
           N'Casa' AS mando, nome_fora AS adversario, posicao_fora AS posicao_adversario,
           home_club_manager_name AS tecnico, away_club_manager_name AS tecnico_adversario,
           home_club_formation AS formacao, away_club_formation AS formacao_adversario,
           home_club_goals AS gols_pro, away_club_goals AS gols_contra
    FROM partidas
    UNION ALL
    SELECT match_id, away_team_id, game_id, away_club_id,
           competition_id, season, date, match_week, nome_casa, nome_fora,
           home_club_goals, away_club_goals,
           N'Fora', nome_casa, posicao_casa,
           away_club_manager_name, home_club_manager_name,
           away_club_formation, home_club_formation,
           away_club_goals, home_club_goals
    FROM partidas
)
INSERT INTO dw.dim_partida (sb_match_id, sb_team_id, tm_game_id, tm_club_id, data, temporada, liga,
                            rodada, confronto, mando, adversario, posicao_adversario_2015_16,
                            tecnico, tecnico_adversario, formacao, formacao_adversario,
                            gols_pro, gols_contra, resultado)
SELECT x.match_id, x.sb_team_id, x.game_id, x.tm_club_id, x.date,
       CONCAT(x.season, '/', RIGHT(x.season + 1, 2)),
       l.nome,
       x.match_week,
       CONCAT(x.nome_casa, ' ', x.home_club_goals, ' x ', x.away_club_goals, ' ', x.nome_fora),
       x.mando, x.adversario, x.posicao_adversario,
       x.tecnico, x.tecnico_adversario, x.formacao, x.formacao_adversario,
       x.gols_pro, x.gols_contra,
       CASE WHEN x.gols_pro > x.gols_contra THEN N'Vitória'
            WHEN x.gols_pro = x.gols_contra THEN N'Empate'
            ELSE N'Derrota' END
FROM lados x
JOIN dw.dim_liga l ON l.tm_competition_id = x.competition_id
ORDER BY x.date, x.match_id, x.mando;

RAISERROR('dw.dim_partida ok', 0, 1) WITH NOWAIT;
GO

-- ---------------------------------------------------------------------
-- dw.dim_partida: posse (D17.4), base do PAdj da fato_desempenho
-- * Posse = participação do time nos passes da partida, sem lateral,
--   como no levantamento (D6.5).
-- * SUM(...) OVER (PARTITION BY match_id) soma os passes dos dois
--   times sem agrupar as linhas.
-- Conferido em 2026-11-10: 3.034/3.034 iguais ao gabarito.
-- ---------------------------------------------------------------------
WITH passes AS (
    SELECT match_id, team_id, COUNT(*) AS passes
    FROM stg.sb_events
    WHERE type_name = N'Pass'
      AND (pass_type IS NULL OR pass_type <> N'Throw-in')
    GROUP BY match_id, team_id
),
posse AS (
    SELECT match_id, team_id,
           passes * 1.0 / SUM(passes) OVER (PARTITION BY match_id) AS posse
    FROM passes
)
UPDATE p
SET p.posse = CAST(x.posse AS DECIMAL(5,4))
FROM dw.dim_partida p
JOIN posse x ON x.match_id = p.sb_match_id
            AND x.team_id  = p.sb_team_id;

RAISERROR('dw.dim_partida posse ok', 0, 1) WITH NOWAIT;
GO

-- ---------------------------------------------------------------------
-- dw.dim_jogador: os 2.176 jogadores do StatsBomb 2015/16 (D16)
-- * Só as colunas do StatsBomb; as outras 7 ficam NULL até o UPDATE da
--   aula da fato_desempenho e do Bloco 2.
-- * N'''''' (dois apóstrofos) -> N'''' (um): o JSON traz alguns nomes
--   com o apóstrofo duplicado (N''Golo, O''Shea). Aspas duplas também
--   viram apóstrofo (D18.3: David N"Gog, Charles N"Zogbia).
-- * DISTINCT na CTE 1: a escalação tem uma linha por trecho de posição;
--   sem ele, "mais partidas" contaria trechos.
-- * Time pelo team_id e nome pela dim_time: algumas escalações trazem
--   outro nome para o mesmo time ("Marseille" x "Olympique de
--   Marseille", "Caen" x "Stade Malherbe Caen"); contando por nome, as
--   trocas de time viravam 145 em vez de 103.
-- * ROW_NUMBER escolhe a versão campeã (nome e país com mais partidas,
--   time do último jogo); a 2ª coluna do ORDER BY só desempata.
-- * LEFT JOIN no país: o Henok Goitom não tem país em nenhuma escalação.
-- Conferido em 2026-11-09: igual ao gabarito (EXCEPT 0/0).
-- ---------------------------------------------------------------------
TRUNCATE TABLE dw.dim_jogador;

WITH escalacoes AS (        -- 1. uma linha por jogador × partida, com o apóstrofo corrigido
    SELECT DISTINCT l.player_id, l.match_id, m.match_date, l.team_id, dt.nome AS time_nome, l.country_name,
           REPLACE(REPLACE(l.player_name, N'''''', N''''), N'"', N'''') AS nome_completo,
           REPLACE(REPLACE(COALESCE(l.player_nickname, l.player_name), N'''''', N''''), N'"', N'''') AS nome
    FROM stg.sb_lineups l
    JOIN stg.sb_matches m ON m.match_id = l.match_id
    JOIN dw.dim_time dt   ON dt.sb_team_id = l.team_id
),
nomes AS (                  -- 2. a versão do nome com mais partidas
    SELECT player_id, nome, nome_completo,
           ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY COUNT(*) DESC, nome_completo) AS ordem
    FROM escalacoes
    GROUP BY player_id, nome, nome_completo
),
paises AS (                 -- 3. o país com mais partidas
    SELECT player_id, country_name,
           ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY COUNT(*) DESC, country_name) AS ordem
    FROM escalacoes
    WHERE country_name IS NOT NULL
    GROUP BY player_id, country_name
),
ultimo_jogo AS (            -- 4. o time do último jogo da temporada
    SELECT player_id, time_nome,
           ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY match_date DESC) AS ordem
    FROM escalacoes
),
times AS (                  -- 5. quantos times e se jogou pelo Chelsea
    SELECT player_id,
           COUNT(DISTINCT team_id) AS qtd_times,
           MAX(CASE WHEN time_nome = N'Chelsea' THEN 1 ELSE 0 END) AS jogou_chelsea
    FROM escalacoes
    GROUP BY player_id
)
INSERT INTO dw.dim_jogador (sb_player_id, nome, nome_completo, pais, time_fim_2015_16,
                            trocou_de_time_2015_16, eh_elenco_chelsea_2015_16)
SELECT t.player_id, n.nome, n.nome_completo, p.country_name, u.time_nome,
       CASE WHEN t.qtd_times > 1 THEN 1 ELSE 0 END,
       t.jogou_chelsea
FROM times t
JOIN nomes n            ON n.player_id = t.player_id AND n.ordem = 1
JOIN ultimo_jogo u      ON u.player_id = t.player_id AND u.ordem = 1
LEFT JOIN paises p      ON p.player_id = t.player_id AND p.ordem = 1
ORDER BY t.player_id;

RAISERROR('dw.dim_jogador ok', 0, 1) WITH NOWAIT;
GO

-- ---------------------------------------------------------------------
-- stg.sb_trechos: os 56.884 trechos de posição com os minutos certos
-- (D17.1 e D17.3), base dos minutos da fato_desempenho.
-- * Fim de cada tempo = último lance do período: entram os acréscimos
--   dos dois tempos (o relógio do 2º tempo recomeça em 45:00 = 2700, e
--   o método do levantamento perdia o acréscimo do 1º tempo).
-- * Trecho sem hora de fim vai até o fim do 2º tempo.
-- * 9 trechos vêm da origem com início e fim trocados (começam no 2º
--   tempo e terminam no 1º); os eventos confirmam que vão do fim do 1º
--   tempo ao começo do 2º. A CTE 4 desfaz a troca.
-- * Corte dos expulsos (D8): todo trecho que termina depois do vermelho
--   ou do 2º amarelo passa a terminar no cartão. A escalação quase nunca
--   registra a expulsão (Courtois, Chelsea 2 x 2 Swansea City: vermelho
--   aos 51:37, mas segue no gol até 53:40 e depois "vira meia" até o
--   apito). Trecho que começa depois do cartão fica com 0 segundo
--   (segundo_fim menor que segundo_inicio).
-- * periodo * 10000 + segundo compara momentos de tempos diferentes
--   (o 2º tempo sempre vem depois do 1º).
-- * GREATEST (SQL Server 2022+) impede tempo negativo.
-- Conferido em 2026-11-10: igual ao gabarito (EXCEPT 0/0).
-- ---------------------------------------------------------------------
TRUNCATE TABLE stg.sb_trechos;

WITH fim_tempo AS (         -- 1. fim de cada tempo = último lance do período
    SELECT match_id,
           MAX(CASE WHEN period = 1 THEN minute * 60 + second END) AS fim_1t,
           MAX(CASE WHEN period = 2 THEN minute * 60 + second END) AS fim_2t
    FROM stg.sb_events
    GROUP BY match_id
),
expulsoes AS (              -- 2. momento do vermelho ou do 2º amarelo (D8)
    SELECT match_id, player_id, period AS periodo, minute * 60 + second AS segundo
    FROM stg.sb_events
    WHERE card IN (N'Red Card', N'Second Yellow')
),
relogio AS (                -- 3. início e fim em segundos do relógio (o 2º tempo começa em 45:00 = 2700)
    SELECT l.match_id, l.team_id, l.player_id, l.position_seq, l.position_id,
           l.from_period AS periodo_de,
           CAST(LEFT(l.from_time, CHARINDEX(':', l.from_time) - 1) AS INT) * 60
             + CAST(RIGHT(l.from_time, 2) AS INT) AS segundo_de,
           COALESCE(l.to_period, 2) AS periodo_ate,                  -- sem fim = até o apito
           COALESCE(CAST(LEFT(l.to_time, CHARINDEX(':', l.to_time) - 1) AS INT) * 60
             + CAST(RIGHT(l.to_time, 2) AS INT), f.fim_2t) AS segundo_ate,
           f.fim_1t
    FROM stg.sb_lineups l
    JOIN fim_tempo f ON f.match_id = l.match_id
),
trechos AS (                -- 4. desfaz os 9 trechos com início e fim trocados (do 2º tempo para o 1º)
    SELECT r.match_id, r.team_id, r.player_id, r.position_seq, r.position_id, r.fim_1t,
           IIF(r.periodo_de > r.periodo_ate, r.periodo_ate, r.periodo_de)   AS periodo_inicio,
           IIF(r.periodo_de > r.periodo_ate, r.segundo_ate, r.segundo_de)   AS segundo_inicio,
           IIF(r.periodo_de > r.periodo_ate, r.periodo_de,  r.periodo_ate)  AS periodo_fim,
           IIF(r.periodo_de > r.periodo_ate, r.segundo_de,  r.segundo_ate)  AS segundo_fim,
           x.periodo AS periodo_cartao, x.segundo AS segundo_cartao
    FROM relogio r
    LEFT JOIN expulsoes x ON x.match_id = r.match_id AND x.player_id = r.player_id
),
cortados AS (               -- 5. se o cartão veio antes do fim do trecho, o trecho termina no cartão
    SELECT match_id, team_id, player_id, position_seq, position_id, fim_1t,
           periodo_inicio, segundo_inicio,
           CASE WHEN periodo_cartao * 10000 + segundo_cartao < periodo_fim * 10000 + segundo_fim
                THEN 1 ELSE 0 END AS cortado_expulsao,
           CASE WHEN periodo_cartao * 10000 + segundo_cartao < periodo_fim * 10000 + segundo_fim
                THEN periodo_cartao ELSE periodo_fim END AS periodo_fim,
           CASE WHEN periodo_cartao * 10000 + segundo_cartao < periodo_fim * 10000 + segundo_fim
                THEN segundo_cartao ELSE segundo_fim END AS segundo_fim
    FROM trechos
)
INSERT INTO stg.sb_trechos (match_id, team_id, player_id, position_seq, position_id,
                             periodo_inicio, segundo_inicio, periodo_fim, segundo_fim,
                             cortado_expulsao, segundos)
SELECT match_id, team_id, player_id, position_seq, position_id,
       periodo_inicio, segundo_inicio, periodo_fim, segundo_fim, cortado_expulsao,
       -- 6. parte no 1º tempo + parte no 2º tempo (nunca negativa)
       CASE WHEN periodo_inicio = 1
            THEN GREATEST(0, IIF(periodo_fim = 1, segundo_fim, fim_1t) - segundo_inicio)
            ELSE 0 END
     + CASE WHEN periodo_fim = 2
            THEN GREATEST(0, segundo_fim - IIF(periodo_inicio = 2, segundo_inicio, 2700))
            ELSE 0 END
FROM cortados
ORDER BY match_id, player_id, position_seq;

RAISERROR('stg.sb_trechos ok', 0, 1) WITH NOWAIT;
GO

-- ---------------------------------------------------------------------
-- dw.fato_desempenho: 54.415 linhas jogador × partida × posição (D17)
-- * Base = stg.sb_trechos (minutos, D17.1); os lances entram por LEFT
--   JOIN pela position_id do próprio evento (D17.2): quem jogou sem
--   lance de indicador fica com 0.
-- * Regras dos indicadores = levantamento (00_dados/levantamento/
--   Levantamento.cs): passe sem lateral; certo = sem pass_outcome;
--   progressivo = certo, fora de bola parada, termina com x >= 60 e
--   25% mais perto do centro do gol (120, 40); condução progressiva =
--   idem e avança >= 5; desarme e interceptação com Won / Success In
--   Play / Success Out; perda = Dispossessed + Miscontrol.
-- * PAdj = contagem × 0,5 / (1 − posse) com a posse da dim_partida.
-- * Ficam 587 linhas com 0 minuto (troca tática no mesmo segundo ou
--   trecho depois do cartão): 225 têm lances e o "por 90" usa os
--   minutos, então não distorcem.
-- Conferido em 2026-11-10: igual ao gabarito (EXCEPT 0/0); contagens de
-- Terry, Cahill e Matić iguais às do levantamento; 0 órfãos.
-- ---------------------------------------------------------------------
TRUNCATE TABLE dw.fato_desempenho;

WITH minutos AS (           -- 1. minutos por jogador × partida × posição (soma dos trechos)
    SELECT match_id, team_id, player_id, position_id,
           SUM(segundos) / 60.0 AS minutos
    FROM stg.sb_trechos
    GROUP BY match_id, team_id, player_id, position_id
),
lances AS (                 -- 2. os lances que entram nos indicadores, com as contas de apoio
    SELECT match_id, team_id, player_id, position_id, type_name,
           pass_type, pass_outcome, pass_shot_assist, pass_goal_assist,
           dribble_outcome, duel_type, duel_outcome, interception_outcome,
           ball_recovery_recovery_failure, aerial_won, shot_outcome, shot_statsbomb_xg,
           location_x, pass_end_location_x, carry_end_location_x,
           CASE WHEN type_name = N'Pass' AND (pass_type IS NULL OR pass_type <> N'Throw-in')
                THEN 1 ELSE 0 END AS eh_passe,
           -- distância até o centro do gol (120, 40)
           SQRT(SQUARE(120 - location_x)           + SQUARE(40 - location_y))           AS dist_inicio,
           SQRT(SQUARE(120 - pass_end_location_x)  + SQUARE(40 - pass_end_location_y))  AS dist_fim_passe,
           SQRT(SQUARE(120 - carry_end_location_x) + SQUARE(40 - carry_end_location_y)) AS dist_fim_conducao,
           -- área: x >= 102 e y entre 18 e 62
           CASE WHEN location_x >= 102 AND location_y BETWEEN 18 AND 62
                THEN 1 ELSE 0 END AS inicio_na_area,
           CASE WHEN pass_end_location_x >= 102 AND pass_end_location_y BETWEEN 18 AND 62
                THEN 1 ELSE 0 END AS fim_na_area
    FROM stg.sb_events
    WHERE player_id IS NOT NULL
      AND type_name IN (N'Pass', N'Carry', N'Dribble', N'Duel', N'Interception', N'Ball Recovery',
                        N'Pressure', N'Error', N'Dispossessed', N'Miscontrol', N'Clearance', N'Shot')
),
contagens AS (              -- 3. as contagens por jogador × partida × posição (regras do levantamento)
    SELECT match_id, team_id, player_id, position_id,
           SUM(eh_passe) AS passes,
           SUM(CASE WHEN eh_passe = 1 AND pass_outcome IS NULL THEN 1 ELSE 0 END) AS passes_certos,
           SUM(CASE WHEN eh_passe = 1 AND pass_outcome IS NULL
                     AND (pass_type IS NULL OR pass_type NOT IN (N'Corner', N'Free Kick', N'Goal Kick', N'Kick Off'))
                     AND pass_end_location_x >= 60
                     AND dist_fim_passe <= 0.75 * dist_inicio THEN 1 ELSE 0 END) AS passes_progressivos,
           SUM(CASE WHEN eh_passe = 1 AND (pass_shot_assist = 1 OR pass_goal_assist = 1)
                    THEN 1 ELSE 0 END) AS passes_chave,
           SUM(CASE WHEN eh_passe = 1 AND pass_outcome IS NULL
                     AND inicio_na_area = 0 AND fim_na_area = 1 THEN 1 ELSE 0 END) AS passes_area,
           SUM(CASE WHEN type_name = N'Carry'
                     AND carry_end_location_x >= 60
                     AND dist_fim_conducao <= 0.75 * dist_inicio
                     AND carry_end_location_x - location_x >= 5 THEN 1 ELSE 0 END) AS conducoes_progressivas,
           SUM(CASE WHEN type_name = N'Dribble' THEN 1 ELSE 0 END) AS dribles,
           SUM(CASE WHEN type_name = N'Dribble' AND dribble_outcome = N'Complete' THEN 1 ELSE 0 END) AS dribles_certos,
           SUM(CASE WHEN type_name = N'Duel' AND duel_type = N'Tackle'
                     AND duel_outcome IN (N'Won', N'Success In Play', N'Success Out') THEN 1 ELSE 0 END) AS desarmes_ganhos,
           SUM(CASE WHEN type_name = N'Interception'
                     AND interception_outcome IN (N'Won', N'Success In Play', N'Success Out') THEN 1 ELSE 0 END) AS interceptacoes,
           SUM(CASE WHEN type_name = N'Ball Recovery' AND ball_recovery_recovery_failure IS NULL
                    THEN 1 ELSE 0 END) AS recuperacoes,
           SUM(CASE WHEN type_name = N'Pressure' THEN 1 ELSE 0 END) AS pressoes,
           SUM(CASE WHEN aerial_won = 1 THEN 1 ELSE 0 END) AS duelos_aereos_ganhos,
           SUM(CASE WHEN type_name = N'Duel' AND duel_type = N'Aerial Lost' THEN 1 ELSE 0 END) AS duelos_aereos_perdidos,
           SUM(CASE WHEN type_name IN (N'Dispossessed', N'Miscontrol') THEN 1 ELSE 0 END) AS perdas_bola,
           SUM(CASE WHEN type_name = N'Error' THEN 1 ELSE 0 END) AS erros_levaram_chute,
           SUM(CASE WHEN type_name = N'Shot' THEN 1 ELSE 0 END) AS chutes,
           SUM(CASE WHEN type_name = N'Shot' AND shot_outcome = N'Goal' THEN 1 ELSE 0 END) AS gols,
           SUM(CASE WHEN type_name = N'Shot' THEN shot_statsbomb_xg ELSE 0 END) AS xg,
           SUM(CASE WHEN eh_passe = 1 AND pass_goal_assist = 1 THEN 1 ELSE 0 END) AS assistencias
    FROM lances
    GROUP BY match_id, team_id, player_id, position_id
)
INSERT INTO dw.fato_desempenho (
    sk_jogador, sk_partida, sk_posicao, sk_time, sk_liga, sk_data, minutos,
    passes, passes_certos, passes_progressivos, passes_chave, passes_area,
    conducoes_progressivas, dribles, dribles_certos,
    desarmes_ganhos, interceptacoes, recuperacoes, pressoes, duelos_aereos_ganhos, duelos_aereos_perdidos,
    perdas_bola, erros_levaram_chute, chutes, gols, xg, assistencias,
    desarmes_padj, interceptacoes_padj, recuperacoes_padj, pressoes_padj)
SELECT j.sk_jogador, p.sk_partida, po.sk_posicao, t.sk_time, l.sk_liga, d.sk_data,
       CAST(m.minutos AS DECIMAL(6,2)),
       ISNULL(c.passes, 0), ISNULL(c.passes_certos, 0), ISNULL(c.passes_progressivos, 0),
       ISNULL(c.passes_chave, 0), ISNULL(c.passes_area, 0),
       ISNULL(c.conducoes_progressivas, 0), ISNULL(c.dribles, 0), ISNULL(c.dribles_certos, 0),
       ISNULL(c.desarmes_ganhos, 0), ISNULL(c.interceptacoes, 0), ISNULL(c.recuperacoes, 0),
       ISNULL(c.pressoes, 0), ISNULL(c.duelos_aereos_ganhos, 0), ISNULL(c.duelos_aereos_perdidos, 0),
       ISNULL(c.perdas_bola, 0), ISNULL(c.erros_levaram_chute, 0),
       ISNULL(c.chutes, 0), ISNULL(c.gols, 0), ISNULL(c.xg, 0), ISNULL(c.assistencias, 0),
       -- 5. PAdj com a posse do time na partida
       ISNULL(c.desarmes_ganhos, 0) * 0.5 / (1 - p.posse),
       ISNULL(c.interceptacoes, 0)  * 0.5 / (1 - p.posse),
       ISNULL(c.recuperacoes, 0)    * 0.5 / (1 - p.posse),
       ISNULL(c.pressoes, 0)        * 0.5 / (1 - p.posse)
FROM minutos m              -- 4. a base são os trechos; os lances entram por LEFT JOIN
JOIN dw.dim_jogador j   ON j.sb_player_id = m.player_id
JOIN dw.dim_partida p   ON p.sb_match_id = m.match_id AND p.sb_team_id = m.team_id
JOIN dw.dim_posicao po  ON po.sb_position_id = m.position_id
JOIN dw.dim_time t      ON t.sb_team_id = m.team_id
JOIN stg.sb_matches sm  ON sm.match_id = m.match_id
JOIN dw.dim_liga l      ON l.sb_competition_id = sm.competition_id
JOIN dw.dim_data d      ON d.data = p.data
LEFT JOIN contagens c   ON c.match_id = m.match_id AND c.team_id = m.team_id
                       AND c.player_id = m.player_id AND c.position_id = m.position_id
ORDER BY j.sk_jogador, p.sk_partida, po.sk_posicao;

RAISERROR('dw.fato_desempenho ok', 0, 1) WITH NOWAIT;
GO

-- ---------------------------------------------------------------------
-- dw.dim_jogador: grupo e posição principais (D16.3 e D17.5)
-- * Pelos minutos da fato_desempenho (acréscimos e corte dos expulsos).
-- * Primeiro o grupo com mais minutos, depois a posição com mais minutos
--   dentro dele: os dois ficam sempre coerentes (Kenedy: Ponta, porque
--   soma mais em Ponta do que em Lateral, mesmo com Lateral esquerdo
--   sendo a posição de mais minutos). Pegando a posição primeiro, 68
--   jogadores ficariam num grupo que não é o de mais minutos.
-- * É só o rótulo: o mínimo de 900 minutos continua sendo por grupo, em
--   DAX (D6.3). Kanté tem 1.722 min de Meia central e 1.408 de Volante:
--   rótulo "Meia central", mas entra na comparação dos dois grupos.
-- Conferido em 2026-11-10: igual ao gabarito (EXCEPT 0/0).
-- ---------------------------------------------------------------------
WITH minutos AS (           -- 1. minutos de cada jogador em cada posição (as 4 ligas)
    SELECT f.sk_jogador, p.grupo, p.posicao_pt, p.ordem_grupo, p.sb_position_id,
           SUM(f.minutos) AS minutos
    FROM dw.fato_desempenho f
    JOIN dw.dim_posicao p ON p.sk_posicao = f.sk_posicao
    GROUP BY f.sk_jogador, p.grupo, p.posicao_pt, p.ordem_grupo, p.sb_position_id
),
grupos AS (                 -- 2. o grupo com mais minutos (empate: o de menor ordem_grupo)
    SELECT sk_jogador, grupo,
           ROW_NUMBER() OVER (PARTITION BY sk_jogador
                              ORDER BY SUM(minutos) DESC, MIN(ordem_grupo)) AS ordem
    FROM minutos
    GROUP BY sk_jogador, grupo
),
posicoes AS (               -- 3. dentro desse grupo, a posição com mais minutos
    SELECT m.sk_jogador, m.grupo, m.posicao_pt,
           ROW_NUMBER() OVER (PARTITION BY m.sk_jogador
                              ORDER BY m.minutos DESC, m.sb_position_id) AS ordem
    FROM minutos m
    JOIN grupos g ON g.sk_jogador = m.sk_jogador
                 AND g.grupo = m.grupo
                 AND g.ordem = 1
)
UPDATE j
SET j.grupo_principal   = x.grupo,
    j.posicao_principal = x.posicao_pt
FROM dw.dim_jogador j
JOIN posicoes x ON x.sk_jogador = j.sk_jogador
               AND x.ordem = 1;

RAISERROR('dw.dim_jogador posicao principal ok', 0, 1) WITH NOWAIT;
GO

-- ---------------------------------------------------------------------
-- stg.ligacao_jogadores + dw.dim_jogador.tm_player_id (D18)
-- * Elencos de 2015/16 nas duas fontes: #sb (jogador x time com minutos
--   na fato, 2.279 pares) e #tm (quem atuou pelos 80 clubes na
--   temporada, em qualquer competição). Tabelas temporárias: só existem
--   nesta sessão.
-- * Regras em ordem, sem acento (COLLATE ..._CI_AI), dentro do clube, só
--   quem ainda não foi ligado e só com 1 candidato de cada lado:
--   1 nome TM = apelido SB; 2 = nome completo SB; 3 último sobrenome
--   igual; 4 todas as palavras do nome TM no apelido + nome completo SB
--   (hífen separa palavras, ponto sai); 5 exceções conferidas à mão.
-- * Đ/đ viram Dj/dj antes de comparar (Đoković = Djokovic): o CI_AI não
--   faz essa troca.
-- * Resultado em 2026-11-10: 2.142 + 10 + 57 + 52 = 99,50% dos minutos
--   pelas regras; com as 18 exceções, 100%. Nenhum jogador com dois IDs.
--   Só o Markel Susaeta difere nos minutos (1.985 x 0): o TM não tem as
--   atuações dele em 2015/16.
-- * O UPDATE no fim grava o tm_player_id; o índice único filtrado da
--   dim_jogador impede dois jogadores do StatsBomb com o mesmo ID do TM.
-- Conferido em 2026-11-10: igual ao gabarito (EXCEPT 0/0).
-- ---------------------------------------------------------------------
TRUNCATE TABLE stg.ligacao_jogadores;

-- 1. Elenco do StatsBomb: cada jogador × time com minutos na fato (2.279 pares)
DROP TABLE IF EXISTS #sb;
SELECT DISTINCT j.sb_player_id, t.sb_team_id, t.tm_club_id,
       REPLACE(j.nome, N'đ', N'dj')          AS nome,           -- Đoković -> Djoković (D18.1)
       REPLACE(j.nome_completo, N'đ', N'dj') AS nome_completo,
       -- apelido + nome completo numa frase só, com espaço nas pontas, para a regra 4
       CONCAT(N' ', REPLACE(REPLACE(REPLACE(CONCAT(j.nome, N' ', j.nome_completo),
                                            N'đ', N'dj'), N'-', N' '), N'.', N''), N' ') AS palavras
INTO #sb
FROM dw.fato_desempenho f
JOIN dw.dim_jogador j ON j.sk_jogador = f.sk_jogador
JOIN dw.dim_time t    ON t.sk_time = f.sk_time;

-- 2. Elenco do Transfermarkt: quem atuou pelos 80 clubes em 2015/16 (qualquer competição)
DROP TABLE IF EXISTS #tm;
SELECT DISTINCT a.player_club_id AS tm_club_id, a.player_id AS tm_player_id, p.name AS tm_nome
INTO #tm
FROM stg.tm_appearances a
JOIN stg.tm_games g   ON g.game_id = a.game_id
JOIN stg.tm_players p ON p.player_id = a.player_id
WHERE g.season = 2015
  AND a.player_club_id IN (SELECT tm_club_id FROM dw.dim_time);

-- 3. Regras 1 a 4, uma de cada vez. Cada uma só olha quem ainda não foi ligado
--    e só liga quando há exatamente 1 candidato de cada lado.

-- Regra 1: nome TM = apelido SB
WITH candidatos AS (
    SELECT s.sb_player_id, s.sb_team_id, s.tm_club_id, t.tm_player_id
    FROM #sb s
    JOIN #tm t ON t.tm_club_id = s.tm_club_id
              AND t.tm_nome COLLATE Latin1_General_100_CI_AI = s.nome COLLATE Latin1_General_100_CI_AI
    WHERE NOT EXISTS (SELECT 1 FROM stg.ligacao_jogadores l WHERE l.sb_player_id = s.sb_player_id AND l.sb_team_id = s.sb_team_id)
      AND NOT EXISTS (SELECT 1 FROM stg.ligacao_jogadores l WHERE l.tm_player_id = t.tm_player_id AND l.tm_club_id = t.tm_club_id)
),
unicos AS (
    SELECT *, COUNT(*) OVER (PARTITION BY sb_player_id, sb_team_id) AS n_sb,
              COUNT(*) OVER (PARTITION BY tm_player_id, tm_club_id) AS n_tm
    FROM candidatos
)
INSERT INTO stg.ligacao_jogadores (sb_player_id, sb_team_id, tm_player_id, tm_club_id, regra)
SELECT sb_player_id, sb_team_id, tm_player_id, tm_club_id, 1
FROM unicos WHERE n_sb = 1 AND n_tm = 1;

-- Regra 2: nome TM = nome completo SB
WITH candidatos AS (
    SELECT s.sb_player_id, s.sb_team_id, s.tm_club_id, t.tm_player_id
    FROM #sb s
    JOIN #tm t ON t.tm_club_id = s.tm_club_id
              AND t.tm_nome COLLATE Latin1_General_100_CI_AI = s.nome_completo COLLATE Latin1_General_100_CI_AI
    WHERE NOT EXISTS (SELECT 1 FROM stg.ligacao_jogadores l WHERE l.sb_player_id = s.sb_player_id AND l.sb_team_id = s.sb_team_id)
      AND NOT EXISTS (SELECT 1 FROM stg.ligacao_jogadores l WHERE l.tm_player_id = t.tm_player_id AND l.tm_club_id = t.tm_club_id)
),
unicos AS (
    SELECT *, COUNT(*) OVER (PARTITION BY sb_player_id, sb_team_id) AS n_sb,
              COUNT(*) OVER (PARTITION BY tm_player_id, tm_club_id) AS n_tm
    FROM candidatos
)
INSERT INTO stg.ligacao_jogadores (sb_player_id, sb_team_id, tm_player_id, tm_club_id, regra)
SELECT sb_player_id, sb_team_id, tm_player_id, tm_club_id, 2
FROM unicos WHERE n_sb = 1 AND n_tm = 1;

-- Regra 3: último sobrenome igual (última palavra do nome completo SB e do nome TM)
WITH candidatos AS (
    SELECT s.sb_player_id, s.sb_team_id, s.tm_club_id, t.tm_player_id
    FROM #sb s
    JOIN #tm t ON t.tm_club_id = s.tm_club_id
              AND RIGHT(t.tm_nome, CHARINDEX(N' ', REVERSE(t.tm_nome) + N' ') - 1) COLLATE Latin1_General_100_CI_AI
                = RIGHT(s.nome_completo, CHARINDEX(N' ', REVERSE(s.nome_completo) + N' ') - 1) COLLATE Latin1_General_100_CI_AI
    WHERE NOT EXISTS (SELECT 1 FROM stg.ligacao_jogadores l WHERE l.sb_player_id = s.sb_player_id AND l.sb_team_id = s.sb_team_id)
      AND NOT EXISTS (SELECT 1 FROM stg.ligacao_jogadores l WHERE l.tm_player_id = t.tm_player_id AND l.tm_club_id = t.tm_club_id)
),
unicos AS (
    SELECT *, COUNT(*) OVER (PARTITION BY sb_player_id, sb_team_id) AS n_sb,
              COUNT(*) OVER (PARTITION BY tm_player_id, tm_club_id) AS n_tm
    FROM candidatos
)
INSERT INTO stg.ligacao_jogadores (sb_player_id, sb_team_id, tm_player_id, tm_club_id, regra)
SELECT sb_player_id, sb_team_id, tm_player_id, tm_club_id, 3
FROM unicos WHERE n_sb = 1 AND n_tm = 1;

-- Regra 4: todas as palavras do nome TM aparecem no apelido + nome completo SB
WITH candidatos AS (
    SELECT s.sb_player_id, s.sb_team_id, s.tm_club_id, t.tm_player_id
    FROM #sb s
    JOIN #tm t ON t.tm_club_id = s.tm_club_id
    WHERE NOT EXISTS (                 -- nenhuma palavra do nome TM fica de fora
              SELECT 1
              FROM STRING_SPLIT(REPLACE(REPLACE(t.tm_nome, N'-', N' '), N'.', N''), N' ') w
              WHERE w.value <> N''
                AND s.palavras COLLATE Latin1_General_100_CI_AI NOT LIKE N'% ' + w.value + N' %')
      AND NOT EXISTS (SELECT 1 FROM stg.ligacao_jogadores l WHERE l.sb_player_id = s.sb_player_id AND l.sb_team_id = s.sb_team_id)
      AND NOT EXISTS (SELECT 1 FROM stg.ligacao_jogadores l WHERE l.tm_player_id = t.tm_player_id AND l.tm_club_id = t.tm_club_id)
),
unicos AS (
    SELECT *, COUNT(*) OVER (PARTITION BY sb_player_id, sb_team_id) AS n_sb,
              COUNT(*) OVER (PARTITION BY tm_player_id, tm_club_id) AS n_tm
    FROM candidatos
)
INSERT INTO stg.ligacao_jogadores (sb_player_id, sb_team_id, tm_player_id, tm_club_id, regra)
SELECT sb_player_id, sb_team_id, tm_player_id, tm_club_id, 4
FROM unicos WHERE n_sb = 1 AND n_tm = 1;

-- Regra 5: exceções conferidas à mão (D18.2). Liga o jogador em todos os times dele.
WITH excecoes AS (
    SELECT sb_player_id, tm_player_id
    FROM (VALUES
        (3058,   50935,  N'Apelido no TM: Chicharito'),
        (3601,   177862, N'Apelido no TM: Charly Musonda Jr.'),
        (5558,   2904,   N'Apelido no TM: Rafa Márquez'),
        (6390,   54245,  N'Markel Susaeta: sem atuação no TM em 2015/16'),
        (6559,   126625, N'Apelido no TM: Juankar'),
        (6788,   71559,  N'Apelido no TM: Xabi Etxeita'),
        (9636,   314237, N'Rushian Hepburn-Murphy: sem atuação no TM em 2015/16'),
        (18721,  242532, N'Apelido no TM: Rober Ibáñez'),
        (18946,  73846,  N'Grafia no TM: Paul-José Mpoku'),
        (24132,  212867, N'Apelido no TM: Fran Varela'),
        (24782,  343273, N'Apelido no TM: Joni Montiel'),
        (26087,  7631,   N'Grafia no TM: Carlos Gurpegui'),
        (26764,  37892,  N'Grafia no TM: Ion Ansotegi'),
        (27053,  27394,  N'Apelido no TM: Alex Song'),
        (40348,  336704, N'Assane Gnoukouri = Alassane Traoré no TM (mesma data de nascimento)'),
        (42946,  156934, N'Jiang Guangtai = Tyias Browning (mudou de nome ao se naturalizar chinês)'),
        (386651, 38592,  N'Apelido no TM: Juanito Gómez'),
        (398941, 87893,  N'Grafia no TM: Vasyl Pryima')
    ) AS e (sb_player_id, tm_player_id, motivo)
)
INSERT INTO stg.ligacao_jogadores (sb_player_id, sb_team_id, tm_player_id, tm_club_id, regra)
SELECT s.sb_player_id, s.sb_team_id, e.tm_player_id, s.tm_club_id, 5
FROM #sb s
JOIN excecoes e ON e.sb_player_id = s.sb_player_id
WHERE NOT EXISTS (SELECT 1 FROM stg.ligacao_jogadores l WHERE l.sb_player_id = s.sb_player_id AND l.sb_team_id = s.sb_team_id);

-- tm_player_id na dim_jogador (D18.4)
UPDATE j
SET j.tm_player_id = l.tm_player_id
FROM dw.dim_jogador j
JOIN (SELECT DISTINCT sb_player_id, tm_player_id
      FROM stg.ligacao_jogadores) l ON l.sb_player_id = j.sb_player_id;

RAISERROR('stg.ligacao_jogadores ok', 0, 1) WITH NOWAIT;
GO

-- ---------------------------------------------------------------------
-- dw.dim_jogador: Bloco 2 (D19.1)
-- * INSERT dos 5 do elenco do Chelsea 2014/15 que não jogaram em 2015/16
--   (Drogba, Schürrle, Christensen, Izzy Brown, Solanke), com
--   sb_player_id NULL. Vêm antes do UPDATE, para receber os atributos.
--   País com a grafia do StatsBomb, pelo país mais frequente entre os
--   ligados com o mesmo país no TM (Cote d'Ivoire -> Côte d'Ivoire).
-- * UPDATE de nascimento, idade em 01/07/2016 (anos completos), pé em
--   português e altura, da stg.tm_players. Os buracos vêm do TM (1 sem
--   nascimento, 16 sem pé, 10 sem altura) e ficam NULL.
-- Conferido em 2026-11-10: igual ao gabarito (EXCEPT 0/0).
-- ---------------------------------------------------------------------
-- D19.1: os 5 do elenco do Chelsea 2014/15 que não jogaram em 2015/16 (fora do StatsBomb)
WITH chelsea_14_15 AS (
    SELECT DISTINCT a.player_id
    FROM stg.tm_appearances a
    JOIN stg.tm_games g ON g.game_id = a.game_id
    WHERE g.season = 2014
      AND a.player_club_id = 631                       -- Chelsea no Transfermarkt
)
INSERT INTO dw.dim_jogador (sb_player_id, tm_player_id, nome, pais,
                            trocou_de_time_2015_16, eh_elenco_chelsea_2015_16)
SELECT NULL, p.player_id, p.name,
       COALESCE(sb.pais, p.country_of_citizenship),    -- país com a grafia do StatsBomb
       0, 0
FROM chelsea_14_15 c
JOIN stg.tm_players p ON p.player_id = c.player_id
-- grafia do StatsBomb: o país mais frequente entre os ligados com o mesmo país no TM
-- (o TM escreve "Cote d'Ivoire", o StatsBomb "Côte d'Ivoire")
OUTER APPLY (
    SELECT TOP 1 j.pais
    FROM dw.dim_jogador j
    JOIN stg.tm_players p2 ON p2.player_id = j.tm_player_id
    WHERE p2.country_of_citizenship = p.country_of_citizenship
      AND j.pais IS NOT NULL
    GROUP BY j.pais
    ORDER BY COUNT(*) DESC
) sb
WHERE NOT EXISTS (SELECT 1 FROM dw.dim_jogador j WHERE j.tm_player_id = c.player_id)
ORDER BY p.player_id;

-- D19.1: nascimento, idade em 01/07/2016 (D6.6), pé em português e altura
UPDATE j
SET j.data_nascimento = CAST(p.date_of_birth AS DATE),
    -- anos completos: diferença de anos, menos 1 se o aniversário ainda não chegou em 01/07/2016
    j.idade_2016 = DATEDIFF(YEAR, p.date_of_birth, '20160701')
                 - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, p.date_of_birth, '20160701'), p.date_of_birth) > '20160701'
                        THEN 1 ELSE 0 END,
    j.pe = CASE p.foot WHEN N'right' THEN N'Direito'
                       WHEN N'left'  THEN N'Esquerdo'
                       WHEN N'both'  THEN N'Ambos' END,
    j.altura_cm = p.height_in_cm
FROM dw.dim_jogador j
JOIN stg.tm_players p ON p.player_id = j.tm_player_id;

RAISERROR('dw.dim_jogador Bloco 2 ok', 0, 1) WITH NOWAIT;
GO

-- =====================================================================
-- CONFERÊNCIAS
-- =====================================================================

-- ---------------------------------------------------------------------
-- dw.dim_data
-- Esperado: 4.748 dias, de 2014-01-01 a 2026-12-31; 14 temporadas
--           (2013/14 com 181 dias e 2026/27 com 184, incompletas; 2015/16
--           com 366); 20150807 (1ª rodada da PL) Sexta-Feira, 2015/16;
--           20160630 Quinta-Feira, 'Até a janela de 2016'; 20160701
--           Sexta-Feira, 2016/17, 'Depois'; 912 dias até a janela e 3.836
--           depois.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS dias, MIN(data) AS primeiro, MAX(data) AS ultimo
FROM dw.dim_data;

SELECT *
FROM dw.dim_data
WHERE sk_data IN (20150807, 20160229, 20160630, 20160701);

SELECT temporada, MIN(data) AS inicio, MAX(data) AS fim, COUNT(*) AS dias
FROM dw.dim_data
GROUP BY temporada
ORDER BY temporada;

SELECT periodo_cenario, COUNT(*) AS dias
FROM dw.dim_data
GROUP BY periodo_cenario;
GO

-- ---------------------------------------------------------------------
-- dw.dim_liga
-- Esperado: 69 linhas, 4 ligas do estudo com código do StatsBomb (Premier
--           League 2, La Liga 11, Serie A 12, Ligue 1 7); tipos:
--           Competição europeia 6, Copa nacional 12, Liga nacional 31,
--           Mundial de Clubes 1, Playoff 3, Seleções 5, Supercopa 11
--           (nenhuma 'Outra'); 0 atuações órfãs.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS linhas,
       SUM(CAST(eh_liga_do_estudo AS INT)) AS ligas_do_estudo,
       COUNT(sb_competition_id) AS com_codigo_statsbomb
FROM dw.dim_liga;

SELECT tipo, COUNT(*) AS competicoes
FROM dw.dim_liga
GROUP BY tipo
ORDER BY tipo;

SELECT *
FROM dw.dim_liga
WHERE eh_liga_do_estudo = 1 OR tipo = N'Competição europeia'
ORDER BY tipo, nome;

SELECT COUNT(*) AS atuacoes_orfas
FROM stg.tm_appearances a
WHERE NOT EXISTS (SELECT 1 FROM dw.dim_liga l WHERE l.tm_competition_id = a.competition_id);
GO

-- ---------------------------------------------------------------------
-- dw.dim_posicao
-- Esperado: 25 linhas, 10 do escopo; 9 grupos (Goleiro 1, Zagueiro 3,
--           Lateral 4, Volante 3, Meia central 3, Meia aberto 2, Meia
--           ofensivo 3, Ponta 2, Atacante 4); trechos das escalações por
--           setor: Goleiro 3.081, Defesa 16.627, Meio 21.645, Ataque
--           15.531 (56.884, a stg.sb_lineups inteira); 0 sem posição.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS linhas, SUM(CAST(eh_escopo AS INT)) AS posicoes_escopo
FROM dw.dim_posicao;

SELECT setor, grupo, COUNT(*) AS posicoes
FROM dw.dim_posicao
GROUP BY ordem_grupo, grupo, setor
ORDER BY ordem_grupo;

SELECT d.setor, COUNT(*) AS trechos
FROM stg.sb_lineups l
JOIN dw.dim_posicao d ON d.sb_position_id = l.position_id
GROUP BY d.ordem_setor, d.setor
ORDER BY d.ordem_setor;

SELECT COUNT(*) AS trechos_sem_posicao
FROM stg.sb_lineups l
WHERE NOT EXISTS (SELECT 1 FROM dw.dim_posicao d WHERE d.sb_position_id = l.position_id);
GO

-- ---------------------------------------------------------------------
-- dw.dim_time
-- Esperado: 80 linhas, 80 clubes TM diferentes, todos com nome_tm e
--           posição; 4 ligas com 20 times e 20 posições cada; 4 primeiros:
--           La Liga Barcelona, Real Madrid, Atlético Madrid, Villarreal;
--           Ligue 1 PSG, Lyon, Monaco, Nice; Premier League Leicester,
--           Arsenal, Tottenham, Manchester City (Chelsea 10º); Serie A
--           Juventus, Napoli, Roma, Inter.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS linhas,
       COUNT(DISTINCT tm_club_id) AS clubes_tm,
       COUNT(nome_tm) AS com_nome_tm,
       COUNT(posicao_2015_16) AS com_posicao
FROM dw.dim_time;

SELECT liga_2015_16, COUNT(*) AS times, COUNT(DISTINCT posicao_2015_16) AS posicoes
FROM dw.dim_time
GROUP BY liga_2015_16;

SELECT liga_2015_16, posicao_2015_16, nome, nome_tm
FROM dw.dim_time
WHERE posicao_2015_16 <= 4 OR nome = N'Chelsea'
ORDER BY liga_2015_16, posicao_2015_16;
GO

-- ---------------------------------------------------------------------
-- dw.dim_partida
-- Esperado: 3.034 linhas, 1.517 partidas SB e 1.517 jogos TM, técnico
--           em todas; espelho casa × fora: Casa V 675 / E 402 / D 440,
--           Fora V 440 / E 402 / D 675; Chelsea: Hiddink 21 jogos
--           7/11/3 (38 x 26), Mourinho 16 jogos 4/3/9 (18 x 26), Steve
--           Holland 1 jogo 1/0/0 (3 x 1) = 12/14/12, 59 x 53.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS linhas,
       COUNT(DISTINCT sb_match_id) AS partidas_sb,
       COUNT(DISTINCT tm_game_id) AS jogos_tm,
       COUNT(tecnico) AS com_tecnico
FROM dw.dim_partida;

SELECT mando, resultado, COUNT(*) AS linhas
FROM dw.dim_partida
GROUP BY mando, resultado
ORDER BY mando, resultado;

SELECT p.tecnico, COUNT(*) AS jogos,
       SUM(CASE WHEN p.resultado = N'Vitória' THEN 1 ELSE 0 END) AS vitorias,
       SUM(CASE WHEN p.resultado = N'Empate'  THEN 1 ELSE 0 END) AS empates,
       SUM(CASE WHEN p.resultado = N'Derrota' THEN 1 ELSE 0 END) AS derrotas,
       SUM(p.gols_pro) AS gols_pro, SUM(p.gols_contra) AS gols_contra
FROM dw.dim_partida p
JOIN dw.dim_time t ON t.sb_team_id = p.sb_team_id
WHERE t.nome = N'Chelsea'
GROUP BY p.tecnico;
GO

-- ---------------------------------------------------------------------
-- dw.dim_jogador
-- Esperado: 2.176 jogadores, 2.175 com país (Henok Goitom sem), 103
--           trocaram de time, 28 do elenco do Chelsea (27 terminam no
--           Chelsea; Juan Cuadrado termina na Juventus), 0 nomes com
--           apóstrofo duplicado; Fernandinho (Fernando Luiz Rosa),
--           N'Golo Kanté (Leicester City), John O'Shea, Mamadou N'Diaye.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS jogadores,
       COUNT(pais) AS com_pais,
       SUM(CAST(trocou_de_time_2015_16 AS INT)) AS trocaram_de_time,
       SUM(CAST(eh_elenco_chelsea_2015_16 AS INT)) AS elenco_chelsea,
       SUM(CASE WHEN nome LIKE N'%''''%' THEN 1 ELSE 0 END) AS apostrofo_duplo
FROM dw.dim_jogador;

SELECT sb_player_id, nome, nome_completo, pais, time_fim_2015_16
FROM dw.dim_jogador
WHERE sb_player_id IN (3054, 3961, 16890, 40700);

SELECT nome, time_fim_2015_16, trocou_de_time_2015_16
FROM dw.dim_jogador
WHERE eh_elenco_chelsea_2015_16 = 1
ORDER BY nome;
GO

-- ---------------------------------------------------------------------
-- stg.sb_trechos
-- Esperado: 56.884 trechos, 3.163.699,0 minutos, 751 trechos cortados
--           de 406 expulsos, 736 trechos com 0 segundo, 2.176 jogadores,
--           1.517 partidas. Em campo por jogo × time: 2.909 normais, 94
--           abaixo de 10,5 (todos com expulsão), 31 acima de 11 (erro da
--           origem, ex.: Waguè, Udinese), nenhum abaixo sem expulsão.
-- ---------------------------------------------------------------------
-- 1. Totais
SELECT COUNT(*)                                     AS trechos,
       CAST(SUM(segundos) / 60.0 AS DECIMAL(10,1))  AS minutos,
       SUM(CAST(cortado_expulsao AS INT))           AS trechos_cortados,
       COUNT(DISTINCT CASE WHEN cortado_expulsao = 1
                           THEN CONCAT(match_id, '-', player_id) END) AS expulsos,
       SUM(CASE WHEN segundos = 0 THEN 1 ELSE 0 END) AS trechos_zerados,
       COUNT(DISTINCT player_id)                    AS jogadores,
       COUNT(DISTINCT match_id)                     AS partidas
FROM stg.sb_trechos;

-- 2. Jogadores em campo por jogo × time (minutos do time / duração do jogo)
WITH duracao AS (
    SELECT match_id,
           MAX(CASE WHEN period = 1 THEN minute * 60 + second END)
         + MAX(CASE WHEN period = 2 THEN minute * 60 + second END) - 2700 AS segundos_jogo
    FROM stg.sb_events
    GROUP BY match_id
),
por_time AS (
    SELECT t.match_id, t.team_id,
           SUM(t.segundos) * 1.0 / d.segundos_jogo AS em_campo,
           MAX(CAST(t.cortado_expulsao AS INT))    AS teve_expulsao
    FROM stg.sb_trechos t
    JOIN duracao d ON d.match_id = t.match_id
    GROUP BY t.match_id, t.team_id, d.segundos_jogo
),
faixas AS (
    SELECT CASE WHEN em_campo > 11.01 THEN N'acima de 11 (erro da origem)'
                WHEN em_campo < 10.5 AND teve_expulsao = 1 THEN N'abaixo de 10,5, com expulsão'
                WHEN em_campo < 10.5 THEN N'abaixo de 10,5, SEM expulsão'
                ELSE N'normal' END AS faixa
    FROM por_time
)
SELECT faixa, COUNT(*) AS jogos_x_time
FROM faixas
GROUP BY faixa
ORDER BY faixa;

-- 3. Courtois no Chelsea 2 x 2 Swansea City (08/08/2015): vermelho aos 51:37 do 2º tempo
SELECT position_seq, position_id, periodo_inicio, segundo_inicio,
       periodo_fim, segundo_fim, cortado_expulsao, segundos
FROM stg.sb_trechos
WHERE match_id = 3754078 AND player_id = 3509
ORDER BY position_seq;

-- 4. Chelsea: quem mais jogou
SELECT TOP 5 j.nome, CAST(SUM(t.segundos) / 60.0 AS DECIMAL(7,1)) AS minutos
FROM stg.sb_trechos t
JOIN dw.dim_jogador j ON j.sb_player_id = t.player_id
JOIN dw.dim_time dt   ON dt.sb_team_id = t.team_id
WHERE dt.nome = N'Chelsea'
GROUP BY j.nome
ORDER BY minutos DESC;
GO

-- ---------------------------------------------------------------------
-- dw.dim_partida (posse) e dw.fato_desempenho
-- Esperado: posse em 3.034/3.034 (0,2218 a 0,7782); fato com 54.415
--           linhas = grão dos trechos, 3.163.699,69 minutos, 1.411.553
--           passes, 3.869 gols, xG 3.746,8447146780, 587 linhas com 0
--           minuto; Terry, Cahill e Matić com as contagens do
--           levantamento; interceptações por jogo do Chelsea 5,92 (20º
--           na Premier League) e 6,73 com PAdj (14º); 0 órfãos.
-- ---------------------------------------------------------------------
-- 1. Posse na dim_partida
SELECT COUNT(*) AS linhas, COUNT(posse) AS com_posse,
       MIN(posse) AS menor, MAX(posse) AS maior
FROM dw.dim_partida;

-- 2. Totais da fato (nenhuma linha perdida nos JOINs: tem que ser igual ao grão dos trechos)
SELECT COUNT(*) AS linhas,
       (SELECT COUNT(*) FROM (SELECT DISTINCT match_id, team_id, player_id, position_id
                              FROM stg.sb_trechos) g) AS grao_trechos,
       SUM(minutos) AS minutos,
       SUM(passes) AS passes, SUM(gols) AS gols, SUM(xg) AS xg,
       SUM(CASE WHEN minutos = 0 THEN 1 ELSE 0 END) AS linhas_0_minuto
FROM dw.fato_desempenho;

-- 3. Mesmos números do levantamento (Terry, Cahill e Matić na Premier League)
SELECT j.nome, SUM(f.minutos) AS minutos, SUM(f.passes) AS passes, SUM(f.passes_certos) AS certos,
       SUM(f.passes_progressivos) AS progressivos, SUM(f.conducoes_progressivas) AS conducoes,
       SUM(f.desarmes_ganhos) AS desarmes, SUM(f.interceptacoes) AS intercept,
       SUM(f.recuperacoes) AS recuperacoes, SUM(f.pressoes) AS pressoes,
       SUM(f.duelos_aereos_ganhos) AS aereos_ganhos, SUM(f.duelos_aereos_perdidos) AS aereos_perdidos
FROM dw.fato_desempenho f
JOIN dw.dim_jogador j ON j.sk_jogador = f.sk_jogador
WHERE j.nome IN (N'John Terry', N'Gary Cahill', N'Nemanja Matić')
GROUP BY j.nome
ORDER BY j.nome;

-- 4. Interceptações por jogo na Premier League: bruta × ajustada por posse (PAdj)
WITH por_time AS (
    SELECT t.nome,
           SUM(f.interceptacoes) * 1.0 / COUNT(DISTINCT f.sk_partida)      AS intercept_jogo,
           SUM(f.interceptacoes_padj) / COUNT(DISTINCT f.sk_partida)       AS intercept_padj_jogo
    FROM dw.fato_desempenho f
    JOIN dw.dim_time t ON t.sk_time = f.sk_time
    JOIN dw.dim_liga l ON l.sk_liga = f.sk_liga
    WHERE l.nome = N'Premier League'
    GROUP BY t.nome
)
SELECT nome,
       CAST(intercept_jogo AS DECIMAL(5,2))      AS intercept_jogo,
       RANK() OVER (ORDER BY intercept_jogo DESC)      AS lugar_bruto,
       CAST(intercept_padj_jogo AS DECIMAL(5,2)) AS intercept_padj_jogo,
       RANK() OVER (ORDER BY intercept_padj_jogo DESC) AS lugar_padj
FROM por_time
ORDER BY lugar_padj;

-- Órfãos (D11.2): toda chave da fato existe na dimensão
SELECT SUM(CASE WHEN j.sk_jogador IS NULL THEN 1 ELSE 0 END)  AS orfaos_jogador,
       SUM(CASE WHEN p.sk_partida IS NULL THEN 1 ELSE 0 END)  AS orfaos_partida,
       SUM(CASE WHEN po.sk_posicao IS NULL THEN 1 ELSE 0 END) AS orfaos_posicao,
       SUM(CASE WHEN t.sk_time IS NULL THEN 1 ELSE 0 END)     AS orfaos_time,
       SUM(CASE WHEN l.sk_liga IS NULL THEN 1 ELSE 0 END)     AS orfaos_liga,
       SUM(CASE WHEN d.sk_data IS NULL THEN 1 ELSE 0 END)     AS orfaos_data
FROM dw.fato_desempenho f
LEFT JOIN dw.dim_jogador j  ON j.sk_jogador = f.sk_jogador
LEFT JOIN dw.dim_partida p  ON p.sk_partida = f.sk_partida
LEFT JOIN dw.dim_posicao po ON po.sk_posicao = f.sk_posicao
LEFT JOIN dw.dim_time t     ON t.sk_time = f.sk_time
LEFT JOIN dw.dim_liga l     ON l.sk_liga = f.sk_liga
LEFT JOIN dw.dim_data d     ON d.sk_data = f.sk_data;
GO

-- ---------------------------------------------------------------------
-- dw.dim_jogador (posição principal) e validação contra o levantamento
-- Esperado: 2.176 com grupo e posição, 0 posições fora do grupo; Goleiro
--           182, Zagueiro 349, Lateral 396, Volante 283, Meia central
--           178, Meia aberto 113, Meia ofensivo 101, Ponta 271, Atacante
--           303. Zagueiros da Premier League com 900+ min no grupo
--           (n = 62), percentil em passe progressivo por 90: Terry 0,
--           Cahill 2, Zouma 5 (levantamento: 0, 0, 5).
-- ---------------------------------------------------------------------
-- 1. Todos preenchidos e coerentes (a posição sempre pertence ao grupo)
SELECT COUNT(*) AS jogadores,
       COUNT(grupo_principal) AS com_grupo,
       COUNT(posicao_principal) AS com_posicao,
       SUM(CASE WHEN p.grupo <> j.grupo_principal THEN 1 ELSE 0 END) AS posicao_fora_do_grupo
FROM dw.dim_jogador j
LEFT JOIN dw.dim_posicao p ON p.posicao_pt = j.posicao_principal;

-- 2. Jogadores por grupo principal
SELECT j.grupo_principal, COUNT(*) AS jogadores
FROM dw.dim_jogador j
JOIN (SELECT DISTINCT grupo, ordem_grupo FROM dw.dim_posicao) g ON g.grupo = j.grupo_principal
GROUP BY j.grupo_principal, g.ordem_grupo
ORDER BY g.ordem_grupo;

-- 3. Elenco do Chelsea
SELECT nome, grupo_principal, posicao_principal
FROM dw.dim_jogador
WHERE eh_elenco_chelsea_2015_16 = 1
ORDER BY grupo_principal, nome;

-- 4. Validação: percentil entre os zagueiros da Premier League com 900+ min no grupo
--    (D6.3). Percentil = % dos outros zagueiros com valor menor, como no levantamento.
WITH zagueiros AS (
    SELECT j.nome, j.eh_elenco_chelsea_2015_16,
           SUM(f.minutos) AS minutos,
           SUM(f.passes_progressivos)    * 90.0 / SUM(f.minutos) AS passes_prog_90,
           SUM(f.conducoes_progressivas) * 90.0 / SUM(f.minutos) AS conducoes_prog_90,
           (SUM(f.desarmes_padj) + SUM(f.interceptacoes_padj)) * 90.0 / SUM(f.minutos) AS desarm_int_padj_90,
           SUM(f.recuperacoes_padj)      * 90.0 / SUM(f.minutos) AS recuperacoes_padj_90
    FROM dw.fato_desempenho f
    JOIN dw.dim_posicao p ON p.sk_posicao = f.sk_posicao
    JOIN dw.dim_liga l    ON l.sk_liga = f.sk_liga
    JOIN dw.dim_jogador j ON j.sk_jogador = f.sk_jogador
    WHERE p.grupo = N'Zagueiro' AND l.nome = N'Premier League'
    GROUP BY j.sk_jogador, j.nome, j.eh_elenco_chelsea_2015_16
    HAVING SUM(f.minutos) >= 900
),
percentis AS (
    SELECT z.*,
           COUNT(*) OVER () AS n,
           (RANK() OVER (ORDER BY passes_prog_90)       - 1) * 100.0 / (COUNT(*) OVER () - 1) AS pct_passes_prog,
           (RANK() OVER (ORDER BY conducoes_prog_90)    - 1) * 100.0 / (COUNT(*) OVER () - 1) AS pct_conducoes_prog,
           (RANK() OVER (ORDER BY desarm_int_padj_90)   - 1) * 100.0 / (COUNT(*) OVER () - 1) AS pct_desarm_int_padj,
           (RANK() OVER (ORDER BY recuperacoes_padj_90) - 1) * 100.0 / (COUNT(*) OVER () - 1) AS pct_recuperacoes_padj
    FROM zagueiros z
)
SELECT nome, n, CAST(minutos AS INT) AS minutos,
       CAST(passes_prog_90 AS DECIMAL(4,2))  AS passes_prog_90,
       CAST(ROUND(pct_passes_prog, 0) AS INT)          AS pct_passes_prog,
       CAST(ROUND(pct_conducoes_prog, 0) AS INT)       AS pct_conducoes_prog,
       CAST(ROUND(pct_desarm_int_padj, 0) AS INT)      AS pct_desarm_int_padj,
       CAST(ROUND(pct_recuperacoes_padj, 0) AS INT)    AS pct_recuperacoes_padj
FROM percentis
WHERE eh_elenco_chelsea_2015_16 = 1
ORDER BY minutos DESC;
GO

-- ---------------------------------------------------------------------
-- stg.ligacao_jogadores
-- Esperado: regras 1 a 5 com 2.142, 10, 57, 52 e 18 pares (95,37%,
--           95,81%, 97,24%, 99,50% e 100,00% dos minutos); 2.279 pares,
--           0 jogador com 2 IDs nos dois sentidos, 2.176 com
--           tm_player_id, 0 nomes com aspas; só o Markel Susaeta com
--           minutos diferentes; no Chelsea, Mikel e Falcao pela regra 4,
--           Clarke-Salter pela 3, Baba Rahman pela 2, os outros 24 pela 1.
-- ---------------------------------------------------------------------
-- 1. Pares e minutos por regra (acumulado)
WITH minutos AS (
    SELECT j.sb_player_id, t.sb_team_id, SUM(f.minutos) AS minutos
    FROM dw.fato_desempenho f
    JOIN dw.dim_jogador j ON j.sk_jogador = f.sk_jogador
    JOIN dw.dim_time t    ON t.sk_time = f.sk_time
    GROUP BY j.sb_player_id, t.sb_team_id
),
por_regra AS (
    SELECT l.regra, COUNT(*) AS pares, SUM(m.minutos) AS minutos
    FROM stg.ligacao_jogadores l
    JOIN minutos m ON m.sb_player_id = l.sb_player_id AND m.sb_team_id = l.sb_team_id
    GROUP BY l.regra
)
SELECT regra, pares,
       CAST(SUM(minutos) OVER (ORDER BY regra) * 100.0
            / (SELECT SUM(minutos) FROM minutos) AS DECIMAL(5,2)) AS pct_minutos_acumulado
FROM por_regra
ORDER BY regra;

-- 2. Coerência: ninguém com dois IDs, e todos os 2.176 com tm_player_id
SELECT (SELECT COUNT(*) FROM stg.ligacao_jogadores) AS pares,
       (SELECT COUNT(*) FROM (SELECT sb_player_id FROM stg.ligacao_jogadores
                              GROUP BY sb_player_id HAVING COUNT(DISTINCT tm_player_id) > 1) x) AS sb_com_2_tm,
       (SELECT COUNT(*) FROM (SELECT tm_player_id FROM stg.ligacao_jogadores
                              GROUP BY tm_player_id HAVING COUNT(DISTINCT sb_player_id) > 1) x) AS tm_com_2_sb,
       (SELECT COUNT(tm_player_id) FROM dw.dim_jogador) AS dim_jogador_com_tm,
       (SELECT COUNT(*) FROM dw.dim_jogador WHERE nome LIKE N'%"%') AS nomes_com_aspas;

-- 3. Conferência pelos minutos de liga das duas fontes (diferença acima de 25% + 90)
WITH sb AS (
    SELECT j.sb_player_id, t.sb_team_id, j.nome, SUM(f.minutos) AS minutos_sb
    FROM dw.fato_desempenho f
    JOIN dw.dim_jogador j ON j.sk_jogador = f.sk_jogador
    JOIN dw.dim_time t    ON t.sk_time = f.sk_time
    GROUP BY j.sb_player_id, t.sb_team_id, j.nome
),
tm AS (
    SELECT a.player_id, a.player_club_id, SUM(a.minutes_played) AS minutos_tm
    FROM stg.tm_appearances a
    JOIN stg.tm_games g ON g.game_id = a.game_id
    WHERE g.season = 2015 AND g.competition_id IN ('GB1', 'ES1', 'IT1', 'FR1')
    GROUP BY a.player_id, a.player_club_id
)
SELECT sb.nome, l.regra, CAST(sb.minutos_sb AS INT) AS minutos_sb, ISNULL(tm.minutos_tm, 0) AS minutos_tm
FROM stg.ligacao_jogadores l
JOIN sb      ON sb.sb_player_id = l.sb_player_id AND sb.sb_team_id = l.sb_team_id
LEFT JOIN tm ON tm.player_id = l.tm_player_id AND tm.player_club_id = l.tm_club_id
WHERE ABS(sb.minutos_sb - ISNULL(tm.minutos_tm, 0)) > 0.25 * sb.minutos_sb + 90;

-- 4. Chelsea: nome nas duas fontes
SELECT j.nome AS nome_sb, p.name AS nome_tm, l.regra
FROM stg.ligacao_jogadores l
JOIN dw.dim_jogador j ON j.sb_player_id = l.sb_player_id
JOIN dw.dim_time t    ON t.sb_team_id = l.sb_team_id
JOIN stg.tm_players p ON p.player_id = l.tm_player_id
WHERE t.nome = N'Chelsea'
ORDER BY l.regra DESC, j.nome;
GO

-- ---------------------------------------------------------------------
-- dw.dim_jogador (Bloco 2)
-- Esperado: 2.181 jogadores (2.176 do StatsBomb), 2.181 com tm_player_id,
--           2.180 com nascimento e idade, 2.165 com pé, 2.171 com altura,
--           idade de 17 a 41; pé Direito 1.577, Esquerdo 527, Ambos 61,
--           NULL 16; novos 2177 a 2181 (Drogba 38 anos, Côte d'Ivoire);
--           Kanté 25, Terry 35, David Luiz 29; 18 com algum atributo NULL.
-- ---------------------------------------------------------------------
-- 1. Totais
SELECT COUNT(*) AS jogadores,
       COUNT(sb_player_id) AS do_statsbomb,
       COUNT(tm_player_id) AS com_tm,
       COUNT(data_nascimento) AS com_nascimento,
       COUNT(idade_2016) AS com_idade,
       COUNT(pe) AS com_pe,
       COUNT(altura_cm) AS com_altura,
       MIN(idade_2016) AS idade_min, MAX(idade_2016) AS idade_max
FROM dw.dim_jogador;

-- 2. Pé
SELECT pe, COUNT(*) AS jogadores
FROM dw.dim_jogador
GROUP BY pe
ORDER BY jogadores DESC;

-- 3. Os 5 novos do Chelsea 2014/15
SELECT sk_jogador, tm_player_id, nome, pais, data_nascimento, idade_2016, pe, altura_cm
FROM dw.dim_jogador
WHERE sb_player_id IS NULL
ORDER BY sk_jogador;

-- 4. Idade na janela de 2016: Kanté (29/03/1991), Terry (07/12/1980), Hazard (07/01/1991)
SELECT nome, data_nascimento, idade_2016, pe, altura_cm
FROM dw.dim_jogador
WHERE nome IN (N'N''Golo Kanté', N'John Terry', N'Eden Hazard', N'Marcos Alonso', N'Michy Batshuayi', N'David Luiz')
ORDER BY nome;

-- 5. Quem ficou sem atributo
SELECT nome, data_nascimento, pe, altura_cm
FROM dw.dim_jogador
WHERE data_nascimento IS NULL OR pe IS NULL OR altura_cm IS NULL
ORDER BY nome;
GO
