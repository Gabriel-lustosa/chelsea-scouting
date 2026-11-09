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
--   [x] dw.dim_posicao                                         Aula 12
--   [x] dw.dim_time                                            Aula 13
--   [x] dw.dim_partida                                         Aula 14
--   [x] dw.dim_jogador                                         Aula 15
--   [ ] dw.fato_desempenho
--   Bloco 2 — Transfermarkt
--   [ ] ligação dos jogadores (times e partidas já no Bloco 1)
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
--   * SET QUOTED_IDENTIFIER ON: o índice filtrado da dim_time exige essa
--     opção (erro 1934 sem ela). O SSMS já liga; o sqlcmd deixa desligada.
--
-- Rodar com:
--   sqlcmd -S localhost -E -C -f 65001 -i 01_sql\04_dw_tabelas.sql
-- =====================================================================

USE chelsea_scouting;
GO

SET QUOTED_IDENTIFIER ON;
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

-- ---------------------------------------------------------------------
-- dw.dim_posicao: as 25 posições do StatsBomb (D6.3, D13). Hierarquia
-- posição -> grupo (9) -> setor (4), com os setores do levantamento.
-- O Secondary Striker (25) entra mesmo sem aparecer nas escalações.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dw.dim_posicao;
CREATE TABLE dw.dim_posicao (
    sk_posicao      INT IDENTITY(1,1) NOT NULL,   -- chave do DW (sai igual ao id do StatsBomb)
    sb_position_id  INT           NOT NULL,       -- chave do StatsBomb: 1 a 25
    posicao         NVARCHAR(40)  NOT NULL,       -- nome do StatsBomb: 'Left Defensive Midfield'
    posicao_pt      NVARCHAR(40)  NOT NULL,       -- 'Volante esquerdo'
    sigla           NVARCHAR(5)   NOT NULL,       -- 'LDM'
    lado            NVARCHAR(10)  NOT NULL,       -- 'Direito', 'Centro', 'Esquerdo'
    grupo           NVARCHAR(20)  NOT NULL,       -- 'Zagueiro', 'Volante'...
    setor           NVARCHAR(10)  NOT NULL,       -- 'Goleiro', 'Defesa', 'Meio', 'Ataque'
    eh_escopo       BIT           NOT NULL,       -- 1 = zagueiro, lateral ou volante (D5)
    ordem_grupo     INT           NOT NULL,       -- 1 Goleiro ... 9 Atacante
    ordem_setor     INT           NOT NULL,       -- 1 Goleiro ... 4 Ataque
    CONSTRAINT pk_dim_posicao PRIMARY KEY (sk_posicao),
    CONSTRAINT uq_dim_posicao_sb_position_id UNIQUE (sb_position_id)
);
GO

-- ---------------------------------------------------------------------
-- dw.dim_time: os 80 times do StatsBomb, já com o clube do Transfermarkt
-- (D14). No Bloco 2 entram os clubes que só existem no TM, com
-- sb_team_id NULL.
-- * Uma UNIQUE comum aceita um NULL só: a chave do StatsBomb fica única
--   por um índice filtrado, que só olha as linhas preenchidas.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dw.dim_time;
CREATE TABLE dw.dim_time (
    sk_time            INT IDENTITY(1,1) NOT NULL,   -- chave do DW
    sb_team_id         INT           NULL,           -- chave do StatsBomb (NULL nos clubes só do TM, Bloco 2)
    tm_club_id         INT           NOT NULL,       -- chave do Transfermarkt
    nome               NVARCHAR(200) NOT NULL,       -- curto, do StatsBomb: 'Chelsea', 'Lazio'
    nome_tm            NVARCHAR(200) NULL,           -- oficial do TM: 'Chelsea FC'
    pais               NVARCHAR(100) NULL,           -- país da liga
    liga_2015_16       NVARCHAR(100) NULL,           -- 'Premier League'...
    posicao_2015_16    INT           NULL,           -- posição final na liga (TM)
    eh_time_do_estudo  BIT           NOT NULL,       -- 1 = um dos 80 times das 4 ligas
    CONSTRAINT pk_dim_time PRIMARY KEY (sk_time),
    CONSTRAINT uq_dim_time_tm_club_id UNIQUE (tm_club_id)
);

CREATE UNIQUE INDEX uq_dim_time_sb_team_id
    ON dw.dim_time (sb_team_id)
    WHERE sb_team_id IS NOT NULL;
GO

-- ---------------------------------------------------------------------
-- dw.dim_partida: grão partida × time (D15). Duas linhas por partida,
-- cada uma vista do lado de um time. As 1.517 do StatsBomb agora; no
-- Bloco 2, os jogos só do TM, com sb_match_id e sb_team_id NULL.
-- * As chaves únicas têm duas colunas: a mesma partida aparece duas
--   vezes (uma por time), mas o par partida + time só uma vez.
-- * Contar partidas no Power BI: DISTINCTCOUNT(sb_match_id).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dw.dim_partida;
CREATE TABLE dw.dim_partida (
    sk_partida                  INT IDENTITY(1,1) NOT NULL,   -- chave do DW (na ordem da data)
    sb_match_id                 INT           NULL,           -- partida StatsBomb (NULL nos jogos só do TM, Bloco 2)
    sb_team_id                  INT           NULL,           -- time StatsBomb deste lado
    tm_game_id                  INT           NOT NULL,       -- jogo Transfermarkt
    tm_club_id                  INT           NOT NULL,       -- clube Transfermarkt deste lado
    data                        DATE          NOT NULL,
    temporada                   NVARCHAR(7)   NOT NULL,       -- '2015/16' (do jogo, D11)
    liga                        NVARCHAR(100) NOT NULL,       -- dim_liga.nome
    rodada                      INT           NULL,           -- 1 a 38
    confronto                   NVARCHAR(200) NOT NULL,       -- 'Chelsea 2 x 2 Swansea City' (mandante primeiro)
    mando                       NVARCHAR(4)   NOT NULL,       -- 'Casa' ou 'Fora'
    adversario                  NVARCHAR(200) NOT NULL,
    posicao_adversario_2015_16  INT           NULL,           -- posição final do adversário
    tecnico                     NVARCHAR(100) NULL,           -- técnico deste lado (TM)
    tecnico_adversario          NVARCHAR(100) NULL,
    formacao                    NVARCHAR(30)  NULL,           -- '4-2-3-1' (TM)
    formacao_adversario         NVARCHAR(30)  NULL,
    gols_pro                    INT           NOT NULL,
    gols_contra                 INT           NOT NULL,
    resultado                   NVARCHAR(10)  NOT NULL,       -- 'Vitória', 'Empate', 'Derrota'
    CONSTRAINT pk_dim_partida PRIMARY KEY (sk_partida),
    CONSTRAINT uq_dim_partida_tm UNIQUE (tm_game_id, tm_club_id)
);

CREATE UNIQUE INDEX uq_dim_partida_sb
    ON dw.dim_partida (sb_match_id, sb_team_id)
    WHERE sb_match_id IS NOT NULL;
GO

-- ---------------------------------------------------------------------
-- dw.dim_jogador: os 2.176 jogadores do StatsBomb 2015/16 (D16).
-- * 7 colunas nascem vazias: posicao_principal e grupo_principal são
--   preenchidas na aula da fato_desempenho (minutos certos); tm_player_id,
--   data_nascimento, idade_2016, pe e altura_cm no Bloco 2, depois da
--   ligação com o Transfermarkt.
-- * Índices únicos filtrados nas duas chaves das fontes: no Bloco 2 entra
--   o elenco do Chelsea 2014/15 que não está no StatsBomb (sb_player_id
--   NULL), e até lá o tm_player_id fica NULL em todos.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dw.dim_jogador;
CREATE TABLE dw.dim_jogador (
    sk_jogador                  INT IDENTITY(1,1) NOT NULL,   -- chave do DW
    sb_player_id                INT           NULL,           -- chave do StatsBomb (NULL no Chelsea 2014/15 fora do SB, Bloco 2)
    tm_player_id                INT           NULL,           -- chave do Transfermarkt (Bloco 2)
    nome                        NVARCHAR(200) NOT NULL,       -- 'Willian', 'N''Golo Kanté'
    nome_completo               NVARCHAR(300) NULL,           -- 'Willian Borges da Silva'
    pais                        NVARCHAR(200) NULL,
    time_fim_2015_16            NVARCHAR(200) NULL,           -- time do último jogo da temporada
    trocou_de_time_2015_16      BIT           NOT NULL,       -- 1 = jogou por mais de um time
    eh_elenco_chelsea_2015_16   BIT           NOT NULL,       -- 1 = jogou pelo Chelsea
    posicao_principal           NVARCHAR(40)  NULL,           -- aula da fato_desempenho
    grupo_principal             NVARCHAR(20)  NULL,           -- aula da fato_desempenho
    data_nascimento             DATE          NULL,           -- Bloco 2 (TM)
    idade_2016                  INT           NULL,           -- Bloco 2: idade em 01/07/2016
    pe                          NVARCHAR(10)  NULL,           -- Bloco 2 (TM)
    altura_cm                   INT           NULL,           -- Bloco 2 (TM)
    CONSTRAINT pk_dim_jogador PRIMARY KEY (sk_jogador)
);

CREATE UNIQUE INDEX uq_dim_jogador_sb_player_id
    ON dw.dim_jogador (sb_player_id)
    WHERE sb_player_id IS NOT NULL;

CREATE UNIQUE INDEX uq_dim_jogador_tm_player_id
    ON dw.dim_jogador (tm_player_id)
    WHERE tm_player_id IS NOT NULL;
GO
