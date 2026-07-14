# Steady - backtests a transparent 200-day trend rule on 10yr history -> signals.js
# Rule: hold the stock while it's above its 200-day average; move to cash when below.
# Every claim is measured on REAL history, not predicted.

function Get-Chart($sym,$range,$interval){
  for($try=1;$try -le 4;$try++){
    try { return Invoke-RestMethod "https://query$([int]($try % 2)+1).finance.yahoo.com/v8/finance/chart/$sym`?range=$range&interval=$interval" -Headers @{ "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64)" } }
    catch { Start-Sleep -Milliseconds 500 }
  }
  return $null
}
function MaxDD($eq){ $peak=$eq[0];$mdd=0; foreach($v in $eq){ if($v -gt $peak){$peak=$v}; $dd=($v/$peak-1); if($dd -lt $mdd){$mdd=$dd} }; return $mdd*100 }
function Downsample($a,$n){ if($a.Count -le $n){return $a}; $step=$a.Count/$n; $o=@(); for($i=0;$i -lt $n;$i++){ $o+=[math]::Round($a[[int][math]::Floor($i*$step)],4) }; $o+=[math]::Round($a[-1],4); return $o }

$symbols = Get-Content "$PSScriptRoot\watchlist.txt" | ForEach-Object { $_.Trim().ToUpper() } | Where-Object { $_ -and $_ -notmatch '^#' }
$results=@()

foreach($sym in $symbols){
  $d = Get-Chart $sym "10y" "1d"
  if($null -eq $d -or $null -eq $d.chart.result){ Write-Host "  $sym no data" -ForegroundColor Yellow; continue }
  $c = $d.chart.result[0].indicators.adjclose[0].adjclose | Where-Object { $_ }
  $n = $c.Count
  if($n -lt 260){ Write-Host "  $sym thin data" -ForegroundColor Yellow; continue }

  # rolling 200-day SMA
  $sma=New-Object 'double[]' $n
  $sum=0
  for($i=0;$i -lt $n;$i++){ $sum+=$c[$i]; if($i -ge 200){ $sum-=$c[$i-200] }; if($i -ge 199){ $sma[$i]=$sum/200 } }

  $pos=0; $entry=0; $trades=@()
  $stratEq=@(1.0); $bhEq=@(); $start=$c[199]
  $daysIn=0
  for($i=199;$i -lt $n;$i++){
    $bhEq += ,($c[$i]/$start)
    if($i -gt 199){
      $dayRet = $c[$i]/$c[$i-1]
      $stratEq += ,($stratEq[-1] * ($(if($pos -eq 1){$dayRet}else{1})))
    }
    if($pos -eq 1){ $daysIn++ }
    $above = $c[$i] -gt $sma[$i]
    if($pos -eq 0 -and $above){ $pos=1; $entry=$c[$i] }
    elseif($pos -eq 1 -and -not $above){ $trades += ,($c[$i]/$entry-1); $pos=0 }
  }
  if($pos -eq 1){ $trades += ,($c[-1]/$entry-1) }   # close open trade at last price for stats

  $yrs = ($n-199)/252
  $stratMult=$stratEq[-1]; $bhMult=$bhEq[-1]
  $stratCAGR=([math]::Pow($stratMult,1/$yrs)-1)*100
  $bhCAGR=([math]::Pow($bhMult,1/$yrs)-1)*100
  $wins=($trades | Where-Object { $_ -gt 0 }).Count
  $winRate= if($trades.Count){ [math]::Round($wins/$trades.Count*100) } else { 0 }
  $avgTrade= if($trades.Count){ [math]::Round((($trades|Measure-Object -Average).Average)*100,1) } else { 0 }
  $timeIn=[math]::Round($daysIn/($n-199)*100)

  # current signal
  $above=$c[-1] -gt $sma[-1]; $prevAbove=$c[-2] -gt $sma[-2]
  $sig = if($above -and -not $prevAbove){"BUY"} elseif(-not $above -and $prevAbove){"SELL"} elseif($above){"HOLD"} else{"AVOID"}
  $vsSMA=[math]::Round(($c[-1]/$sma[-1]-1)*100,1)

  $results += [ordered]@{
    sym=$sym; signal=$sig; vsSMA=$vsSMA;
    stratCAGR=[math]::Round($stratCAGR,1); bhCAGR=[math]::Round($bhCAGR,1);
    stratDD=[math]::Round((MaxDD $stratEq),0); bhDD=[math]::Round((MaxDD $bhEq),0);
    trades=$trades.Count; winRate=$winRate; avgTrade=$avgTrade; timeIn=$timeIn; years=[math]::Round($yrs,0);
    stratEq=(Downsample $stratEq 100); bhEq=(Downsample $bhEq 100)
  }
  Write-Host ("  {0,-6} {1,-6} strat {2,5:N1}%/yr  vs B&H {3,5:N1}%/yr  DD {4,4}% vs {5,4}%  {6} trades, {7}% win" -f $sym,$sig,$stratCAGR,$bhCAGR,[math]::Round((MaxDD $stratEq),0),[math]::Round((MaxDD $bhEq),0),$trades.Count,$winRate) -ForegroundColor Green
}

$today=(Get-Date).ToString("yyyy-MM-dd HH:mm")
$json=($results | ConvertTo-Json -Depth 5 -Compress)
"window.STEADY_SIGNALS = { updated: `"$today`", strategy: `"200-day trend model`", signals: $json };" | Out-File "$PSScriptRoot\signals.js" -Encoding utf8
Write-Host "`nSaved signals.js  ($($results.Count) stocks, $today)" -ForegroundColor Cyan