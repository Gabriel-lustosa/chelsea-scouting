<#
.SYNOPSIS
    Baixa os dados brutos do projeto: StatsBomb Open Data 2015/16 e Transfermarkt Datasets.

.DESCRIPTION
    Os dados ficam fora do repositório e fora do OneDrive (decisão D4), em C:\dados\chelsea_scouting:
        statsbomb\matches\<competicao>_27.json   lista de partidas da liga
        statsbomb\events\<match_id>.json         eventos lance a lance (~3 MB por partida)
        statsbomb\lineups\<match_id>.json        escalações, com minutos por posição
        transfermarkt\<tabela>.csv.gz            as 12 tabelas do dcaribou
    Arquivos que já existem são pulados, então dá para rodar de novo para completar um download interrompido.

.PARAMETER Raiz
    Pasta de destino. Padrão: C:\dados\chelsea_scouting

.PARAMETER Ligas
    competition_id do StatsBomb: 2 = Premier League, 11 = La Liga, 12 = Serie A, 7 = Ligue 1.
    Padrão: só a Premier League (~1,1 GB). As 4 ligas somam ~4,6 GB.

.EXAMPLE
    .\00_dados\baixar_dados.ps1
    .\00_dados\baixar_dados.ps1 -Ligas 2,11,12,7
#>
param(
    [string]$Raiz = 'C:\dados\chelsea_scouting',
    [int[]]$Ligas = @(2),
    [switch]$SemTransfermarkt
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$temporada = 27   # season_id da temporada 2015/16 no StatsBomb
$sb = 'https://raw.githubusercontent.com/statsbomb/open-data/master/data'
$tm = 'https://pub-e682421888d945d684bcae8890b0ec20.r2.dev/data'
$wc = New-Object System.Net.WebClient

foreach ($p in 'statsbomb\matches', 'statsbomb\events', 'statsbomb\lineups', 'transfermarkt') {
    New-Item -ItemType Directory -Force (Join-Path $Raiz $p) | Out-Null
}

if (-not $SemTransfermarkt) {
    $tabelas = 'competitions', 'clubs', 'players', 'games', 'appearances', 'player_valuations',
               'club_games', 'game_events', 'game_lineups', 'transfers', 'countries', 'national_teams'
    foreach ($t in $tabelas) {
        $dest = Join-Path $Raiz "transfermarkt\$t.csv.gz"
        if (-not (Test-Path $dest)) { $wc.DownloadFile("$tm/$t.csv.gz", $dest) }
    }
    "Transfermarkt: $($tabelas.Count) tabelas ok"
}

foreach ($liga in $Ligas) {
    $lista = Join-Path $Raiz "statsbomb\matches\${liga}_$temporada.json"
    if (-not (Test-Path $lista)) { $wc.DownloadFile("$sb/matches/$liga/$temporada.json", $lista) }
    $partidas = Get-Content $lista -Raw -Encoding UTF8 | ConvertFrom-Json
    $falhas = @(); $i = 0
    foreach ($id in $partidas.match_id) {
        $i++
        foreach ($tipo in 'events', 'lineups') {
            $dest = Join-Path $Raiz "statsbomb\$tipo\$id.json"
            if (Test-Path $dest) { continue }
            try { $wc.DownloadFile("$sb/$tipo/$id.json", $dest) }
            catch { $falhas += "$tipo/$id"; if (Test-Path $dest) { Remove-Item $dest } }
        }
        if ($i % 50 -eq 0) { "  liga ${liga}: $i de $($partidas.Count)" }
    }
    "StatsBomb liga ${liga}: $($partidas.Count) partidas, falhas: $($falhas.Count) $($falhas -join ', ')"
}
