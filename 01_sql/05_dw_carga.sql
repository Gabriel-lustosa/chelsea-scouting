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
--   [ ] dw.dim_posicao
--   [ ] dw.dim_time
--   [ ] dw.dim_partida
--   [ ] dw.dim_jogador
--   [ ] dw.fato_desempenho
--   Bloco 2 — Transfermarkt
--   [ ] ligação de times, partidas e jogadores
--   [ ] dw.fato_valor_mercado, dw.fato_atuacao, dw.fato_transferencia
--
-- Como funciona:
--   * TRUNCATE antes de cada INSERT: o script pode rodar de novo sem
--     duplicar. Funciona porque não há FK declarada (D11.2).
--   * Datas escritas como 'AAAAMMDD' ('20140101'): esse formato é lido
--     igual em qualquer idioma da sessão (o SET LANGUAGE 'Brazilian'
--     muda a ordem de dia e mês em outros formatos).
--
-- Rodar com (depois do 04_dw_tabelas.sql):
--   sqlcmd -S localhost -E -C -f 65001 -i 01_sql\05_dw_carga.sql
-- =====================================================================

USE chelsea_scouting;
GO

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
