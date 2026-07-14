# Steady - fetches live stock data + computes transparent scorecards into stocks.js
# Reads tickers from watchlist.txt. No account or API key needed.

function Get-Chart($sym,$range,$interval){
  for($try=1;$try -le 4;$try++){
    try {
      $h=@{ "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
      return Invoke-RestMethod "https://query$([int]($try % 2)+1).finance.yahoo.com/v8/finance/chart/$sym`?range=$range&interval=$interval" -Headers $h
    } catch { Start-Sleep -Milliseconds 500 }
  }
  return $null
}
function Stdev($a){ if($a.Count -lt 2){return 0}; $m=($a|Measure-Object -Average).Average; [math]::Sqrt((($a|ForEach-Object{($_-$m)*($_-$m)})|Measure-Object -Sum).Sum/($a.Count-1)) }
function Clamp($v){ [math]::Round([math]::Max(0,[math]::Min(100,$v))) }

$symbols = Get-Content "$PSScriptRoot\watchlist.txt" | ForEach-Object { $_.Trim().ToUpper() } | Where-Object { $_ -and $_ -notmatch '^#' }
$results = @()

foreach($sym in $symbols){
  $d = Get-Chart $sym "1y" "1d"
  if($null -eq $d -or $null -eq $d.chart.result){ Write-Host ("  {0,-6} no data" -f $sym) -ForegroundColor Yellow; continue }
  $res=$d.chart.result[0]; $meta=$res.meta
  $c = $res.indicators.adjclose[0].adjclose | Where-Object { $_ }
  if($c.Count -lt 30){ Write-Host ("  {0,-6} thin data" -f $sym) -ForegroundColor Yellow; continue }

  $price=[double]$meta.regularMarketPrice
  $prev=[double]$meta.chartPreviousClose
  $dayChg=if($prev){[math]::Round(($price/$prev-1)*100,2)}else{0}
  $avg200=($c|Select-Object -Last 200|Measure-Object -Average).Average
  $vsAvg=($price/$avg200-1)*100
  $ret1y=($c[-1]/$c[0]-1)*100
  $rets=@(); for($i=1;$i -lt $c.Count;$i++){ $rets+=($c[$i]/$c[$i-1]-1) }
  $vol=(Stdev $rets)*[math]::Sqrt(252)*100
  $peak=$c[0];$mdd=0; foreach($p in $c){ if($p -gt $peak){$peak=$p}; $dd=($p/$peak-1)*100; if($dd -lt $mdd){$mdd=$dd} }

  $sTrend=Clamp(50+$vsAvg*2.5)
  $sMom=Clamp(50+$ret1y*1.6)
  $sStab=Clamp(100-($vol-15)*2)
  $sDD=Clamp(100+($mdd+10)*2)
  $score=[math]::Round(($sTrend+$sMom+$sStab+$sDD)/4)

  # downsample history to ~52 points for a small sparkline
  $step=[math]::Max(1,[math]::Floor($c.Count/52))
  $spark=@(); for($i=0;$i -lt $c.Count;$i+=$step){ $spark+=[math]::Round($c[$i],2) }

  $results += [ordered]@{
    sym=$sym; name=$meta.longName; price=[math]::Round($price,2); dayChg=$dayChg;
    ret1y=[math]::Round($ret1y,1); vsAvg=[math]::Round($vsAvg,1); vol=[math]::Round($vol,0); mdd=[math]::Round($mdd,0);
    sTrend=$sTrend; sMom=$sMom; sStab=$sStab; sDD=$sDD; score=$score; spark=$spark
  }
  Write-Host ("  {0,-6} `${1,-8} {2,5:N1}%/1yr  score {3}/100" -f $sym,$price,$ret1y,$score) -ForegroundColor Green
}

$today=(Get-Date).ToString("yyyy-MM-dd HH:mm")
$json=($results | ConvertTo-Json -Depth 5 -Compress)
"window.STEADY_STOCKS = { updated: `"$today`", stocks: $json };" | Out-File "$PSScriptRoot\stocks.js" -Encoding utf8
Write-Host "`nSaved stocks.js  ($($results.Count) stocks, $today)" -ForegroundColor Cyan