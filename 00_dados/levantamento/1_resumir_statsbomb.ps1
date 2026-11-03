# Passo 1 do levantamento: lê os 380 arquivos de eventos e escalações da Premier League 2015/16
# e soma os indicadores por time, por setor (Goleiro/Defesa/Meio/Ataque) e por jogador.
# Saídas em <Raiz>\levantamento: times_setores.csv e jogadores.csv (separador ";").
# A leitura dos JSONs é feita em C# (Levantamento.cs) porque o ConvertFrom-Json do PowerShell 5.1 é lento para ~1 GB.
param([string]$Raiz = 'C:\dados\chelsea_scouting')

Add-Type -Path (Join-Path $PSScriptRoot 'Levantamento.cs') -ReferencedAssemblies System.Web.Extensions
$saida = Join-Path $Raiz 'levantamento'
New-Item -ItemType Directory -Force $saida | Out-Null
$t = [Diagnostics.Stopwatch]::StartNew()
[Levantamento]::Roda("$Raiz\statsbomb\events", "$Raiz\statsbomb\lineups", "$Raiz\statsbomb\matches\2_27.json", $saida)
"segundos: $([int]$t.Elapsed.TotalSeconds)"
