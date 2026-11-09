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
--   [ ] dw.dim_liga
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
