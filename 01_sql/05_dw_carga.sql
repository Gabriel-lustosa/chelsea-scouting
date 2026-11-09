-- =====================================================================
-- Projeto: Chelsea 2015/16 — Scouting e Recrutamento
-- Arquivo: 01_sql/05_dw_carga.sql
-- Objetivo: carregar as tabelas do schema dw a partir da staging
--           (TRUNCATE + INSERT, D10.4 e D11.1). As tabelas são criadas
--           pelo 04_dw_tabelas.sql.
--
-- O arquivo é montado aula a aula, junto com o DW no SSMS:
--   Bloco 1 — StatsBomb (D10.2)
--   [x] dw.dim_data        calendário gerado, sem origem        Aula 10
--   [x] dw.dim_liga        65 competições TM + 4 faltantes      Aula 11
--   [x] dw.dim_posicao     25 posições, 9 grupos, 4 setores     Aula 12
--   [x] dw.dim_time        80 times SB ligados ao TM por votação Aula 13
--   [x] dw.dim_partida     1.517 partidas SB x 2 lados (D15)    Aula 14
--   [ ] dw.dim_jogador
--   [ ] dw.fato_desempenho
--   Bloco 2 — Transfermarkt
--   [ ] ligação dos jogadores (times e partidas já no Bloco 1)
--   [ ] dw.dim_time        clubes só do TM (sb_team_id NULL)
--   [ ] dw.dim_partida     jogos só do TM (sb_match_id NULL)
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
