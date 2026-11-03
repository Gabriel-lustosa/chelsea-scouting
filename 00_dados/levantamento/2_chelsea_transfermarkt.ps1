# Passo 2 do levantamento: Chelsea 2014/15 x 2015/16 pelo Transfermarkt.
# Classificação das duas temporadas, minutos/gols/assistências dos jogadores e valor de mercado jul/2015 x jun/2016.
param([string]$Raiz = 'C:\dados\chelsea_scouting')

Add-Type -Path (Join-Path $PSScriptRoot 'FiltraCsv.cs') -ReferencedAssemblies Microsoft.VisualBasic
$tm = "$Raiz\transfermarkt"; $out = "$Raiz\levantamento"
New-Item -ItemType Directory -Force $out | Out-Null

# Recorte da Premier League (GB1) nas tabelas grandes; o Chelsea é o club_id 631
[void][FiltraCsv]::Roda("$tm\games.csv.gz", 'competition_id', @('GB1'), "$out\tm_games_gb1.csv")
[void][FiltraCsv]::Roda("$tm\appearances.csv.gz", 'competition_id', @('GB1'), "$out\tm_app_gb1.csv")

# --- Classificação 2014/15 e 2015/16 a partir dos jogos ---
$g = Import-Csv "$out\tm_games_gb1.csv" | Where-Object { $_.season -in '2014', '2015' }
$tab = @{}
foreach ($j in $g) {
    foreach ($lado in 'home', 'away') {
        $outro = if ($lado -eq 'home') { 'away' } else { 'home' }
        $k = "$($j.season)|$($j."${lado}_club_id")"
        if (-not $tab[$k]) { $tab[$k] = [ordered]@{ temporada = $j.season; club_id = $j."${lado}_club_id"; time = $j."${lado}_club_name"; J = 0; P = 0; GP = 0; GC = 0 } }
        $gp = [int]$j."${lado}_club_goals"; $gc = [int]$j."${outro}_club_goals"
        $t = $tab[$k]; $t.J++; $t.GP += $gp; $t.GC += $gc
        $t.P += if ($gp -gt $gc) { 3 } elseif ($gp -eq $gc) { 1 } else { 0 }
    }
}
$class = $tab.Values | ForEach-Object { [pscustomobject]$_ } | Sort-Object temporada, @{e = 'P'; d = $true }, @{e = { $_.GP - $_.GC }; d = $true }
$class | Group-Object temporada | ForEach-Object { $pos = 0; $_.Group | ForEach-Object { $pos++; $_ | Add-Member pos $pos } }
$class | Export-Csv "$out\tm_classificacao.csv" -NoTypeInformation -Encoding UTF8

"=== Chelsea e referências da liga ==="
foreach ($temp in '2014', '2015') {
    $c = $class | Where-Object { $_.temporada -eq $temp }
    $che = $c | Where-Object club_id -eq '631'
    $top4 = $c | Where-Object { $_.pos -le 4 }
    "{0}/{1}: Chelsea {2}º, {3} pts, GP {4}, GC {5} | média liga GP {6:N1} GC {7:N1} | média top 4 GP {8:N1} GC {9:N1} pts {10:N1}" -f $temp, ([int]$temp + 1 - 2000), $che.pos, $che.P, $che.GP, $che.GC,
        ($c | Measure-Object GP -Average).Average, ($c | Measure-Object GC -Average).Average,
        ($top4 | Measure-Object GP -Average).Average, ($top4 | Measure-Object GC -Average).Average, ($top4 | Measure-Object P -Average).Average
}

# --- Jogadores do Chelsea nas duas temporadas ---
$gid = @{}; $g | ForEach-Object { $gid[$_.game_id] = $_.season }
$app = Import-Csv "$out\tm_app_gb1.csv" | Where-Object { $_.player_club_id -eq '631' -and $gid.ContainsKey($_.game_id) }
$ids = $app.player_id | Sort-Object -Unique
[void][FiltraCsv]::Roda("$tm\players.csv.gz", 'player_id', [string[]]$ids, "$out\tm_players_che.csv")
$pl = @{}; Import-Csv "$out\tm_players_che.csv" | ForEach-Object { $pl[$_.player_id] = $_ }

$jog = $app | Group-Object player_id | ForEach-Object {
    $id = $_.Name; $p = $pl[$id]
    $r = [ordered]@{ jogador = $_.Group[0].player_name; posicao = $p.position; sub_posicao = $p.sub_position; nascimento = ($p.date_of_birth -split ' ')[0] }
    foreach ($temp in '2014', '2015') {
        $a = $_.Group | Where-Object { $gid[$_.game_id] -eq $temp }
        $r["min_$temp"] = [int](($a | Measure-Object minutes_played -Sum).Sum)
        $r["gols_$temp"] = [int](($a | Measure-Object goals -Sum).Sum)
        $r["assist_$temp"] = [int](($a | Measure-Object assists -Sum).Sum)
    }
    [pscustomobject]$r
}
$jog = $jog | Sort-Object { $_.min_2014 + $_.min_2015 } -Descending
$jog | Export-Csv "$out\tm_chelsea_jogadores.csv" -NoTypeInformation -Encoding UTF8
""
"=== Jogadores do Chelsea (minutos, gols, assistências na Premier League) ==="
$jog | Where-Object { $_.min_2014 + $_.min_2015 -ge 600 } | Format-Table jogador, sub_posicao, min_2014, gols_2014, assist_2014, min_2015, gols_2015, assist_2015 -AutoSize | Out-String -Width 200

# --- Valor de mercado: perto do início de 2015/16 x perto do fim ---
$idsV = $app | Group-Object player_id | Where-Object { (($_.Group | Where-Object { $gid[$_.game_id] -eq '2015' }) | Measure-Object minutes_played -Sum).Sum -ge 600 } | ForEach-Object Name
[void][FiltraCsv]::Roda("$tm\player_valuations.csv.gz", 'player_id', [string[]]$idsV, "$out\tm_valuations_che.csv")
$val = Import-Csv "$out\tm_valuations_che.csv"
function ValorEm($id, $data) {
    $v = $val | Where-Object { $_.player_id -eq $id -and $_.date -le $data } | Sort-Object date | Select-Object -Last 1
    if ($v) { [math]::Round([double]$v.market_value_in_eur / 1e6, 1) } else { $null }
}
""
"=== Valor de mercado (milhões de euros): jul/2015 x jun/2016, quem jogou 600+ min em 2015/16 ==="
$idsV | ForEach-Object {
    $a = ValorEm $_ '2015-07-31'; $b = ValorEm $_ '2016-06-30'
    [pscustomobject]@{ jogador = $pl[$_].name; sub_posicao = $pl[$_].sub_position; idade_2016 = 2016 - [int]($pl[$_].date_of_birth.Substring(0, 4)); jul2015 = $a; jun2016 = $b; var = if ($a -and $b) { [math]::Round(($b - $a) / $a * 100) } else { $null } }
} | Sort-Object var | Format-Table -AutoSize | Out-String -Width 200
