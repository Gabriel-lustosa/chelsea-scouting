-- =====================================================================
-- Projeto: Chelsea 2015/16 — Scouting e Recrutamento
-- Arquivo: 01_sql/04_dw_tabelas.sql
-- Objetivo: criar as tabelas do modelo estrela no schema dw (D6, D10).
--           Só a estrutura: a carga fica no 05_dw_carga.sql (D11.1).
--           O mesmo script cria as tabelas no banco do SSIS
--           (trocar o USE para chelsea_scouting_ssis).
--
-- O arquivo é montado aula a aula, junto com o DW no SSMS:
--   Bloco 1 — StatsBomb (D10.2)
--   [x] dw.dim_data                                            Aula 10
--   [x] dw.dim_liga                                            Aula 11
--   [ ] dw.dim_posicao
--   [ ] dw.dim_time
--   [ ] dw.dim_partida
--   [ ] dw.dim_jogador
--   [ ] dw.fato_desempenho
--   Bloco 2 — Transfermarkt
--   [ ] ligação de times, partidas e jogadores
--   [ ] dw.fato_valor_mercado, dw.fato_atuacao, dw.fato_transferencia
--
-- Padrões (D10.4 e D11):
--   * Dimensão com chave substituta INT IDENTITY (sk_...) e as chaves das
--     fontes preservadas (sb_..._id, tm_..._id). Exceção: dim_data, com
--     chave inteligente AAAAMMDD.
--   * Sem chave estrangeira declarada (D11.2): FK impede o TRUNCATE da
--     carga. A integridade é conferida no fim da carga de cada fato
--     (linhas órfãs = 0).
--   * Chaves com nome (pk_..., uq_...), para não ficar o nome automático.
--   * DROP TABLE IF EXISTS antes do CREATE: rodar de novo recria a tabela
--     vazia (depois, rodar o 05_dw_carga.sql).
--
-- Rodar com:
--   sqlcmd -S localhost -E -C -f 65001 -i 01_sql\04_dw_tabelas.sql
-- =====================================================================

USE chelsea_scouting;
GO

-- ---------------------------------------------------------------------
-- dw.dim_data: um dia por linha, de 01/01/2014 a 31/12/2026 (D11.3)
-- A temporada vai de 01/07 a 30/06 (D11.4). A temporada de uma PARTIDA
-- vem da própria partida (dim_partida): 221 jogos das 4 ligas em 2019/20
-- foram depois de 30/06/2020 (pandemia).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dw.dim_data;
CREATE TABLE dw.dim_data (
    sk_data               INT           NOT NULL,   -- AAAAMMDD, ex.: 20160630
    data                  DATE          NOT NULL,
    ano                   INT           NOT NULL,
    trimestre             INT           NOT NULL,   -- 1 a 4
    mes                   INT           NOT NULL,   -- 1 a 12
    mes_nome              NVARCHAR(20)  NOT NULL,   -- 'Janeiro'...
    dia                   INT           NOT NULL,
    dia_semana            INT           NOT NULL,   -- 1 = domingo ... 7 = sábado
    dia_semana_nome       NVARCHAR(20)  NOT NULL,   -- 'Segunda-Feira'...
    eh_fim_semana         BIT           NOT NULL,   -- 1 = sábado ou domingo
    temporada             NVARCHAR(7)   NOT NULL,   -- '2015/16' (01/07 a 30/06)
    temporada_ano_inicio  INT           NOT NULL,   -- 2015 (igual à season do TM)
    periodo_cenario       NVARCHAR(30)  NOT NULL,   -- corte da D6.6 em 30/06/2016
    CONSTRAINT pk_dim_data PRIMARY KEY (sk_data),
    CONSTRAINT uq_dim_data_data UNIQUE (data)
);
GO

-- ---------------------------------------------------------------------
-- dw.dim_liga: 69 competições (D12). As 65 do tm_competitions + 4 que
-- só aparecem nas atuações (CGB, POCP, KLUB, UKRS). sb_competition_id só
-- nas 4 ligas do StatsBomb.
-- IDENTITY(1,1): o banco numera o sk_liga sozinho (começa em 1, soma 1).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dw.dim_liga;
CREATE TABLE dw.dim_liga (
    sk_liga            INT IDENTITY(1,1) NOT NULL,   -- chave do DW
    tm_competition_id  NVARCHAR(10)  NOT NULL,       -- chave do Transfermarkt: GB1, CL...
    sb_competition_id  INT           NULL,           -- chave do StatsBomb (só nas 4 ligas)
    nome               NVARCHAR(100) NOT NULL,
    tipo               NVARCHAR(30)  NOT NULL,       -- 'Liga nacional', 'Copa nacional'...
    pais               NVARCHAR(100) NULL,           -- NULL nas europeias e de seleções
    confederacao       NVARCHAR(20)  NULL,
    eh_liga_do_estudo  BIT           NOT NULL,       -- 1 = uma das 4 ligas do StatsBomb
    CONSTRAINT pk_dim_liga PRIMARY KEY (sk_liga),
    CONSTRAINT uq_dim_liga_tm_competition_id UNIQUE (tm_competition_id)
);
GO
