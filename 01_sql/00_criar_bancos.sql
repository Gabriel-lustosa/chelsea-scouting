-- =====================================================================
-- Projeto: Chelsea 2015/16 — Scouting e Recrutamento
-- Arquivo: 01_sql/00_criar_bancos.sql
-- Objetivo: criar os 2 bancos do projeto, vazios, com as configurações
--           certas para a carga dos JSONs (decisão D7).
--
--   chelsea_scouting       DW oficial, construído em T-SQL (01_sql/).
--                          É ele que alimenta o SSAS e o Power BI.
--   chelsea_scouting_ssis  Banco de teste do SSIS (02_ssis/). Recebe a
--                          mesma estrutura e serve para provar que o SSIS
--                          reproduz o DW feito em SQL (padrão do Olist).
--
-- Configurações (iguais nos 2 bancos):
--   * Collation Latin1_General_100_CI_AS_SC_UTF8: os JSONs do StatsBomb
--     estão em UTF-8. Com o banco em UTF-8, o conteúdo lido do arquivo
--     já vira texto com os acentos certos ("Fàbregas", não "FÃ bregas").
--     CI = não diferencia maiúsculas; AS = diferencia acentos;
--     SC = caracteres suplementares; 100 = versão mais nova das regras.
--   * Recovery SIMPLE: a carga grava ~5 milhões de eventos. No modo FULL
--     o log de transações guardaria tudo até um backup de log; no SIMPLE
--     ele é reaproveitado. Os dados podem ser recarregados dos arquivos
--     em C:\dados a qualquer momento, então não há o que recuperar.
--   * Schemas stg (staging: dados brutos achatados) e dw (dimensões e
--     fatos do modelo estrela, D6). Separam as camadas no próprio nome:
--     stg.evento, dw.fato_desempenho.
--
-- Pode rodar de novo: só cria o que ainda não existe, nunca apaga.
-- Rodar com:
--   sqlcmd -S localhost -E -C -f 65001 -i 01_sql\00_criar_bancos.sql
-- =====================================================================

USE master;
GO

-- ---------------------------------------------------------------------
-- Banco 1: chelsea_scouting (DW oficial)
-- ---------------------------------------------------------------------
IF DB_ID('chelsea_scouting') IS NULL
    CREATE DATABASE chelsea_scouting COLLATE Latin1_General_100_CI_AS_SC_UTF8;
GO

ALTER DATABASE chelsea_scouting SET RECOVERY SIMPLE;
GO

USE chelsea_scouting;
GO

IF SCHEMA_ID('stg') IS NULL EXEC ('CREATE SCHEMA stg');
IF SCHEMA_ID('dw')  IS NULL EXEC ('CREATE SCHEMA dw');
GO

-- ---------------------------------------------------------------------
-- Banco 2: chelsea_scouting_ssis (teste do SSIS)
-- ---------------------------------------------------------------------
USE master;
GO

IF DB_ID('chelsea_scouting_ssis') IS NULL
    CREATE DATABASE chelsea_scouting_ssis COLLATE Latin1_General_100_CI_AS_SC_UTF8;
GO

ALTER DATABASE chelsea_scouting_ssis SET RECOVERY SIMPLE;
GO

USE chelsea_scouting_ssis;
GO

IF SCHEMA_ID('stg') IS NULL EXEC ('CREATE SCHEMA stg');
IF SCHEMA_ID('dw')  IS NULL EXEC ('CREATE SCHEMA dw');
GO

-- ---------------------------------------------------------------------
-- Conferência
-- ---------------------------------------------------------------------
USE master;
GO

SELECT name AS banco, collation_name AS collation, recovery_model_desc AS recovery
FROM sys.databases
WHERE name IN ('chelsea_scouting', 'chelsea_scouting_ssis');
GO
