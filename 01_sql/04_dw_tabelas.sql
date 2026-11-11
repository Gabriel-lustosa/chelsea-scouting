-- =====================================================================
-- Projeto: Chelsea 2015/16 — Scouting e Recrutamento
-- Arquivo: 01_sql/04_dw_tabelas.sql
-- Objetivo: criar as tabelas do modelo estrela no schema dw (D6, D10).
--           Só a estrutura: a carga fica no 05_dw_carga.sql (D11.1).
--           O mesmo script cria as tabelas no banco do SSIS
--           (trocar o USE para chelsea_scouting_ssis).
--
-- O arquivo é montado aula a aula, junto com o DW no SSMS:
--   Bloco 1 — StatsBomb (D10.2) — completo
--   [x] dw.dim_data                                            Aula 10
--   [x] dw.dim_liga                                            Aula 11
--   [x] dw.dim_posicao                                         Aula 12
--   [x] dw.dim_time                                            Aula 13
--   [x] dw.dim_partida                                         Aula 14
--   [x] dw.dim_jogador                                         Aula 15
--   [x] stg.sb_trechos (intermediário da fato)                 Aula 16
--   [x] dw.fato_desempenho (+ coluna posse na dim_partida)     Aula 17
--   Bloco 2 — Transfermarkt — completo
--   [x] stg.ligacao_jogadores (D18)                            Aula 19
--   [x] dw.fato_atuacao                                        Aula 22
--   [x] dw.fato_valor_mercado, dw.fato_transferencia           Aula 23
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
-- * posse: acrescentada na Aula 17 (D17.4) para o PAdj da fato; o 05
--   preenche por UPDATE depois da carga da dim_partida.
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
    rodada                      INT           NULL,           -- 1 a 38; TM: '12. Matchday' -> 12, copa sem rodada
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
    posse                       DECIMAL(5,4)  NULL,           -- participação nos passes, sem lateral (D17.4); NULL nos jogos só do TM
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

-- ---------------------------------------------------------------------
-- stg.sb_trechos: intermediário da fato_desempenho (D17.3), um trecho
-- de posição por linha (56.884), com os minutos certos (D17.1).
-- * Fica na stg (D10.4): é passo da carga, não tabela do modelo.
-- * Tempos em segundos do relógio do StatsBomb: o 2º tempo começa em
--   2700 (45:00).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS stg.sb_trechos;
CREATE TABLE stg.sb_trechos (
    match_id            INT NOT NULL,
    team_id             INT NOT NULL,
    player_id           INT NOT NULL,
    position_seq        INT NOT NULL,   -- ordem do trecho do jogador na partida (1, 2, ...)
    position_id         INT NOT NULL,
    periodo_inicio      INT NOT NULL,   -- 1 ou 2
    segundo_inicio      INT NOT NULL,   -- segundos do relógio: o 2º tempo começa em 2700 (45:00)
    periodo_fim         INT NOT NULL,
    segundo_fim         INT NOT NULL,
    cortado_expulsao    BIT NOT NULL,   -- 1 = trecho encerrado (ou zerado) pelo vermelho / 2º amarelo
    segundos            INT NOT NULL,   -- tempo jogado no trecho, com os acréscimos dos dois tempos
    CONSTRAINT pk_sb_trechos PRIMARY KEY (match_id, player_id, position_seq)
);
GO

-- ---------------------------------------------------------------------
-- dw.fato_desempenho: grão jogador × partida × posição (D6.1), 54.415
-- linhas do StatsBomb 2015/16 (D17).
-- * Contagens com numerador e denominador (passes e passes certos,
--   duelos aéreos ganhos e perdidos): o "por 90" e os % saem no DAX e
--   somam certo em qualquer filtro (D6.2).
-- * sk_partida já leva ao time, à liga e à data, mas as chaves diretas
--   deixam a estrela simples no SSAS e no Power BI (D17.4).
-- * As 4 colunas _padj já vêm ajustadas por posse (D6.5).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dw.fato_desempenho;
CREATE TABLE dw.fato_desempenho (
    -- chaves (D17.4): as 3 primeiras formam o grão jogador × partida × posição
    sk_jogador                  INT            NOT NULL,
    sk_partida                  INT            NOT NULL,   -- partida × time (D15)
    sk_posicao                  INT            NOT NULL,
    sk_time                     INT            NOT NULL,
    sk_liga                     INT            NOT NULL,
    sk_data                     INT            NOT NULL,   -- AAAAMMDD
    -- tempo
    minutos                     DECIMAL(6,2)   NOT NULL,
    -- passe
    passes                      INT            NOT NULL,   -- sem lateral
    passes_certos               INT            NOT NULL,
    passes_progressivos         INT            NOT NULL,
    passes_chave                INT            NOT NULL,   -- assistência para chute ou gol
    passes_area                 INT            NOT NULL,
    -- condução e drible
    conducoes_progressivas      INT            NOT NULL,
    dribles                     INT            NOT NULL,
    dribles_certos              INT            NOT NULL,
    -- defesa
    desarmes_ganhos             INT            NOT NULL,
    interceptacoes              INT            NOT NULL,
    recuperacoes                INT            NOT NULL,
    pressoes                    INT            NOT NULL,
    duelos_aereos_ganhos        INT            NOT NULL,
    duelos_aereos_perdidos      INT            NOT NULL,
    -- erros
    perdas_bola                 INT            NOT NULL,   -- Dispossessed + Miscontrol
    erros_levaram_chute         INT            NOT NULL,
    -- ataque (visão por setor)
    chutes                      INT            NOT NULL,
    gols                        INT            NOT NULL,
    xg                          DECIMAL(12,10) NOT NULL,
    assistencias                INT            NOT NULL,
    -- ajustados por posse (D6.5): contagem × 0,5 / (1 − posse)
    desarmes_padj               DECIMAL(9,4)   NOT NULL,
    interceptacoes_padj         DECIMAL(9,4)   NOT NULL,
    recuperacoes_padj           DECIMAL(9,4)   NOT NULL,
    pressoes_padj               DECIMAL(9,4)   NOT NULL,
    CONSTRAINT pk_fato_desempenho PRIMARY KEY (sk_jogador, sk_partida, sk_posicao)
);
GO

-- ---------------------------------------------------------------------
-- stg.ligacao_jogadores: StatsBomb x Transfermarkt, um par por jogador x
-- time do StatsBomb (2.279), com a regra que casou (D18.4). Fica na stg
-- (D10.4): é passo da carga; o resultado vai para o tm_player_id da
-- dim_jogador. É também o que o SSIS compara por EXCEPT (D10.1).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS stg.ligacao_jogadores;
CREATE TABLE stg.ligacao_jogadores (
    sb_player_id    INT NOT NULL,
    sb_team_id      INT NOT NULL,   -- quem trocou de time tem uma linha por time
    tm_player_id    INT NOT NULL,
    tm_club_id      INT NOT NULL,
    regra           INT NOT NULL,   -- 1 apelido, 2 nome completo, 3 sobrenome, 4 palavras, 5 exceção
    CONSTRAINT pk_ligacao_jogadores PRIMARY KEY (sb_player_id, sb_team_id)
);
GO

-- ---------------------------------------------------------------------
-- dw.fato_atuacao: grão jogador × jogo do Transfermarkt (D6, D19.4),
-- 329.797 atuações dos 2.181 jogadores do DW, de 2014/15 a 2025/26.
-- * sk_partida = jogo × clube do jogador (D15, D19.3).
-- * Sem posição: o TM só dá o jogo. Posição e setor vêm da dim_jogador.
-- * Cartões como o TM grava: 2º amarelo = amarelos 2 e vermelhos 0;
--   vermelhos = 1 só no vermelho direto. Expulsão = amarelos = 2 ou
--   vermelhos = 1 (conferido com os cartões do StatsBomb em 2015/16).
-- * Temporada: filtrar pela dim_partida (temporada do jogo, D11), não
--   pela dim_data.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dw.fato_atuacao;
CREATE TABLE dw.fato_atuacao (
    -- chaves: as 2 primeiras formam o grão jogador × jogo
    sk_jogador      INT  NOT NULL,
    sk_partida      INT  NOT NULL,   -- jogo × clube do jogador (D15)
    sk_time         INT  NOT NULL,   -- clube do jogador no jogo
    sk_liga         INT  NOT NULL,
    sk_data         INT  NOT NULL,   -- AAAAMMDD
    -- medidas
    minutos         INT  NOT NULL,
    gols            INT  NOT NULL,
    assistencias    INT  NOT NULL,
    amarelos        INT  NOT NULL,   -- 2 = expulso pelo 2º amarelo
    vermelhos       INT  NOT NULL,   -- só vermelho direto
    CONSTRAINT pk_fato_atuacao PRIMARY KEY (sk_jogador, sk_partida)
);
GO

-- ---------------------------------------------------------------------
-- dw.fato_valor_mercado: grão jogador × data da avaliação (D19.4),
-- 46.741 avaliações dos jogadores do DW, de 2014 a 2026.
-- * Sem chave de clube (D19.5): o current_club_id do TM não é confiável;
--   o clube na data fica como texto.
-- * O valor do cenário (última avaliação até 30/06/2016, D6.6) sai de
--   uma medida DAX sobre esta fato.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dw.fato_valor_mercado;
CREATE TABLE dw.fato_valor_mercado (
    sk_jogador          INT           NOT NULL,
    sk_data             INT           NOT NULL,   -- AAAAMMDD da avaliação
    valor_eur           BIGINT        NOT NULL,   -- euros
    clube_na_avaliacao  NVARCHAR(200) NOT NULL,   -- nome do clube no TM, como texto (D19.5)
    CONSTRAINT pk_fato_valor_mercado PRIMARY KEY (sk_jogador, sk_data)
);
GO

-- ---------------------------------------------------------------------
-- dw.fato_transferencia: grão jogador × transferência (D19.4, D19.6),
-- 5.716 transferências de 762 jogadores, de 2014 a 2026.
-- * A dim_time entra duas vezes (origem e destino): dimensão de papel
--   duplo. No SSAS e no Power BI uma das relações fica inativa e é
--   usada com USERELATIONSHIP.
-- * taxa_eur NULL = não informada; 0 = sem custo (empréstimo, fim de
--   contrato). A situacao_taxa traz isso em texto.
-- * Chave com 4 colunas: o mesmo jogador pode ter 2 transferências no
--   mesmo dia (Cristante em 01/07/2018), com clubes diferentes.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dw.fato_transferencia;
CREATE TABLE dw.fato_transferencia (
    sk_jogador         INT           NOT NULL,
    sk_data            INT           NOT NULL,   -- AAAAMMDD da transferência
    sk_time_origem     INT           NOT NULL,   -- dim_time no papel de origem
    sk_time_destino    INT           NOT NULL,   -- dim_time no papel de destino
    taxa_eur           BIGINT        NULL,       -- NULL = não informada
    valor_mercado_eur  BIGINT        NULL,       -- valor do TM na data (229 sem valor)
    situacao_taxa      NVARCHAR(20)  NOT NULL,   -- 'Paga', 'Sem custo', 'Não informada'
    CONSTRAINT pk_fato_transferencia PRIMARY KEY (sk_jogador, sk_data, sk_time_origem, sk_time_destino)
);
GO
