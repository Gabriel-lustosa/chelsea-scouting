# Passo 4 do levantamento: percentil de cada jogador do Chelsea (900+ min) dentro do mesmo grupo de posição
# na Premier League 2015/16, com indicadores por 90 minutos. Precisa da saída do passo 1.
param([string]$Raiz = 'C:\dados\chelsea_scouting')
$out = "$Raiz\levantamento"
$ci = [Globalization.CultureInfo]::InvariantCulture
$j = Import-Csv "$out\jogadores.csv" -Delimiter ';'
function Grupo($p) {
    switch -regex ($p) {
        '^Goalkeeper$' { 'Goleiro'; break }
        'Center Back$' { 'Zagueiro'; break }
        '(Left|Right) (Wing )?Back$' { 'Lateral'; break }
        '(Defensive|Center) Midfield$' { 'Volante/Meia central'; break }
        'Attacking Midfield$|Wing$|^(Left|Right) Midfield$' { 'Meia ofensivo/Ponta'; break }
        'Forward$|Striker$' { 'Atacante'; break }
        default { 'Outro' }
    }
}
$met = [ordered]@{
    'xG s/pen'      = { $_.xg_sem_penalti }
    'Passes-chave'  = { $_.passes_chave }
    'Passes área'   = { $_.passes_area }
    'Passes prog.'  = { $_.passes_progressivos }
    'Cond. prog.'   = { $_.conducoes_progressivas }
    'Dribles'       = { $_.dribles_certos }
    'Desarm+Int'    = { [double]::Parse($_.desarmes_ganhos, $ci) + [double]::Parse($_.interceptacoes, $ci) }
    'Recuper.'      = { $_.recuperacoes }
    'Pressões'      = { $_.pressoes }
    'Perdas(-)'     = { $_.perdas_bola }
}
$base = $j | Where-Object { [double]::Parse($_.minutos, $ci) -ge 900 } | ForEach-Object {
    $r = $_; $min = [double]::Parse($r.minutos, $ci)
    $o = [ordered]@{ jogador = $r.jogador; time = $r.time; posicao = $r.posicao_principal; grupo = Grupo $r.posicao_principal; min = [int]$min }
    foreach ($k in $met.Keys) { $o[$k] = [double]::Parse([string](& $met[$k] $r), $ci) / $min * 90 }
    [pscustomobject]$o
}
"Jogadores com 900+ min na liga: $($base.Count)"
""
"Percentil do jogador do Chelsea dentro do mesmo grupo de posição na Premier League (100 = melhor; em Perdas, 100 = perde menos a bola)"
$res = foreach ($c in ($base | Where-Object time -eq 'Chelsea' | Sort-Object grupo, min -Descending)) {
    $pares = $base | Where-Object grupo -eq $c.grupo
    $o = [ordered]@{ jogador = $c.jogador; grupo = $c.grupo; n = $pares.Count; min = $c.min }
    foreach ($k in $met.Keys) {
        $abaixo = ($pares | Where-Object { if ($k -eq 'Perdas(-)') { $_.$k -gt $c.$k } else { $_.$k -lt $c.$k } }).Count
        $o[$k] = [int][math]::Round(100 * $abaixo / [math]::Max(1, $pares.Count - 1))
    }
    [pscustomobject]$o
}
$res | Format-Table -AutoSize | Out-String -Width 250
$res | Export-Csv "$out\chelsea_percentis.csv" -NoTypeInformation -Encoding UTF8
