# Passo 3 do levantamento: posição do Chelsea entre os 20 times em cada indicador (por jogo),
# no total do time, no que sofreu dos adversários e por setor. Confere os gols contra o Transfermarkt.
# Precisa das saídas dos passos 1 e 2.
param([string]$Raiz = 'C:\dados\chelsea_scouting')
$out = "$Raiz\levantamento"
$d = Import-Csv "$out\times_setores.csv" -Delimiter ';'
$num = { param($v) [double]::Parse($v, [Globalization.CultureInfo]::InvariantCulture) }

# Checagem: gols por time x Transfermarkt
$cl = Import-Csv "$out\tm_classificacao.csv" | Where-Object temporada -eq '2015'
$t = $d | Where-Object setor -eq 'Time'; $so = $d | Where-Object setor -eq 'Sofrido'
"Gols StatsBomb (pró/contra) Chelsea: $($($t | ? time -eq 'Chelsea').gols) / $($($so | ? time -eq 'Chelsea').gols) | TM: 59 / 53"
"Soma de gols da liga: StatsBomb $(($t | % { & $num $_.gols } | Measure-Object -Sum).Sum) | TM $(($cl | % { [int]$_.GP } | Measure-Object -Sum).Sum)"
""

function Rank($linhas, $metrica, [scriptblock]$calc, [bool]$maiorMelhor) {
    $vals = $linhas | ForEach-Object { [pscustomobject]@{ time = $_.time; v = (& $calc $_) } }
    $ord = if ($maiorMelhor) { $vals | Sort-Object v -Descending } else { $vals | Sort-Object v }
    $i = 0; $pos = 0; foreach ($o in $ord) { $i++; if ($o.time -eq 'Chelsea') { $pos = $i } }
    $che = ($vals | ? time -eq 'Chelsea').v; $med = ($vals | Measure-Object v -Average).Average
    $top4 = ($vals | ? { $_.time -in 'Leicester City', 'Arsenal', 'Tottenham Hotspur', 'Manchester City' } | Measure-Object v -Average).Average
    [pscustomobject]@{ metrica = $metrica; Chelsea = [math]::Round($che, 2); media_liga = [math]::Round($med, 2); media_top4 = [math]::Round($top4, 2); posicao_Chelsea = "$pos de 20" }
}
function PJ($r, $m) { (& $num $r.$m) / (& $num $r.jogos) }
$jogosPor = @{}; $t | % { $jogosPor[$_.time] = & $num $_.jogos }
function PJs($r, $m) { (& $num $r.$m) / $jogosPor[$r.time] }

"=== TIME: o que o Chelsea produziu (por jogo) ==="
@(
    Rank $t 'Gols' { PJ $args[0] 'gols' } $true
    Rank $t 'xG' { PJ $args[0] 'xg' } $true
    Rank $t 'xG sem pênalti' { PJ $args[0] 'xg_sem_penalti' } $true
    Rank $t 'Chutes' { PJ $args[0] 'chutes' } $true
    Rank $t 'xG por chute' { (& $num $args[0].xg) / (& $num $args[0].chutes) } $true
    Rank $t 'Gols - xG (temporada)' { (& $num $args[0].gols) - (& $num $args[0].gols_contra_proprio) - (& $num $args[0].xg) } $true
    Rank $t 'Passes-chave' { PJ $args[0] 'passes_chave' } $true
    Rank $t 'Passes na área' { PJ $args[0] 'passes_area' } $true
    Rank $t 'Passes progressivos' { PJ $args[0] 'passes_progressivos' } $true
    Rank $t 'Conduções progressivas' { PJ $args[0] 'conducoes_progressivas' } $true
    Rank $t 'Dribles certos' { PJ $args[0] 'dribles_certos' } $true
    Rank $t 'Acerto de passe %' { 100 * (& $num $args[0].passes_certos) / (& $num $args[0].passes) } $true
    Rank $t 'Posse (% dos passes)' { $tm = $args[0].time; 100 * (& $num $args[0].passes) / ((& $num $args[0].passes) + (& $num ($so | ? time -eq $tm).passes)) } $true
    Rank $t 'Desarmes ganhos' { PJ $args[0] 'desarmes_ganhos' } $true
    Rank $t 'Interceptações' { PJ $args[0] 'interceptacoes' } $true
    Rank $t 'Recuperações' { PJ $args[0] 'recuperacoes' } $true
    Rank $t 'Recuperações no terço ofensivo' { PJ $args[0] 'recuperacoes_terco_ofensivo' } $true
    Rank $t 'Pressões' { PJ $args[0] 'pressoes' } $true
    Rank $t 'Erros que viraram chute' { PJ $args[0] 'erros_levaram_chute' } $false
    Rank $t 'Perdas de bola' { PJ $args[0] 'perdas_bola' } $false
    Rank $t 'Duelos aéreos ganhos %' { 100 * (& $num $args[0].duelos_aereos_ganhos) / ((& $num $args[0].duelos_aereos_ganhos) + (& $num $args[0].duelos_aereos_perdidos)) } $true
) | Format-Table -AutoSize | Out-String -Width 200

"=== SOFRIDO: o que os adversários fizeram contra o Chelsea (por jogo; menor = melhor) ==="
@(
    Rank $so 'Gols sofridos' { PJ $args[0] 'gols' } $false
    Rank $so 'xG contra' { PJ $args[0] 'xg' } $false
    Rank $so 'xG contra sem pênalti' { PJ $args[0] 'xg_sem_penalti' } $false
    Rank $so 'Chutes contra' { PJ $args[0] 'chutes' } $false
    Rank $so 'xG por chute contra' { (& $num $args[0].xg) / (& $num $args[0].chutes) } $false
    Rank $so 'Gols sofridos - xG contra (temporada)' { (& $num $args[0].gols) - (& $num $args[0].gols_contra_proprio) - (& $num $args[0].xg) } $false
    Rank $so 'Pênaltis contra (temporada)' { & $num $args[0].penaltis } $false
    Rank $so 'Passes-chave contra' { PJ $args[0] 'passes_chave' } $false
    Rank $so 'Passes na área contra' { PJ $args[0] 'passes_area' } $false
    Rank $so 'Passes progressivos contra' { PJ $args[0] 'passes_progressivos' } $false
) | Format-Table -AutoSize | Out-String -Width 200

foreach ($setor in 'Defesa', 'Meio', 'Ataque') {
    $s = $d | Where-Object setor -eq $setor
    "=== SETOR $($setor.ToUpper()): ações dos jogadores do setor (por jogo do time) ==="
    @(
        Rank $s 'Gols' { PJs $args[0] 'gols' } $true
        Rank $s 'xG sem pênalti' { PJs $args[0] 'xg_sem_penalti' } $true
        Rank $s 'Chutes' { PJs $args[0] 'chutes' } $true
        Rank $s 'Passes-chave' { PJs $args[0] 'passes_chave' } $true
        Rank $s 'Passes na área' { PJs $args[0] 'passes_area' } $true
        Rank $s 'Passes progressivos' { PJs $args[0] 'passes_progressivos' } $true
        Rank $s 'Conduções progressivas' { PJs $args[0] 'conducoes_progressivas' } $true
        Rank $s 'Dribles certos' { PJs $args[0] 'dribles_certos' } $true
        Rank $s 'Desarmes + interceptações' { ((& $num $args[0].desarmes_ganhos) + (& $num $args[0].interceptacoes)) / $jogosPor[$args[0].time] } $true
        Rank $s 'Recuperações' { PJs $args[0] 'recuperacoes' } $true
        Rank $s 'Pressões' { PJs $args[0] 'pressoes' } $true
        Rank $s 'Erros que viraram chute' { PJs $args[0] 'erros_levaram_chute' } $false
        Rank $s 'Perdas de bola' { PJs $args[0] 'perdas_bola' } $false
        Rank $s 'Duelos aéreos ganhos %' { 100 * (& $num $args[0].duelos_aereos_ganhos) / [math]::Max(1, (& $num $args[0].duelos_aereos_ganhos) + (& $num $args[0].duelos_aereos_perdidos)) } $true
    ) | Format-Table -AutoSize | Out-String -Width 200
}
