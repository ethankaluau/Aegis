# Aegis - fetches live crypto data + the same scorecards/price gauges into crypto.js
# Reads coins from crypto-watchlist.txt (e.g. BTC-USD). No account or API key needed.

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
function RSI($c,$period){
  if($c.Count -le $period){ return $null }
  $g=0.0; $l=0.0
  for($i=1;$i -le $period;$i++){ $ch=$c[$i]-$c[$i-1]; if($ch -ge 0){$g+=$ch}else{$l-=$ch} }
  $ag=$g/$period; $al=$l/$period
  for($i=$period+1;$i -lt $c.Count;$i++){
    $ch=$c[$i]-$c[$i-1]
    if($ch -ge 0){ $ag=($ag*($period-1)+$ch)/$period; $al=($al*($period-1))/$period }
    else { $ag=($ag*($period-1))/$period; $al=($al*($period-1)-$ch)/$period }
  }
  if($al -eq 0){ return 100 }
  return [math]::Round(100-100/(1+($ag/$al)),0)
}

$symbols = Get-Content "$PSScriptRoot\crypto-watchlist.txt" | ForEach-Object { $_.Trim().ToUpper() } | Where-Object { $_ -and $_ -notmatch '^#' }
$results = @()

foreach($sym in $symbols){
  $d = Get-Chart $sym "1y" "1d"
  if($null -eq $d -or $null -eq $d.chart.result){ Write-Host ("  {0,-9} no data" -f $sym) -ForegroundColor Yellow; continue }
  $res=$d.chart.result[0]; $meta=$res.meta
  $c = $res.indicators.adjclose[0].adjclose | Where-Object { $_ }
  if($c.Count -lt 30){ Write-Host ("  {0,-9} thin data" -f $sym) -ForegroundColor Yellow; continue }

  $price=[double]$meta.regularMarketPrice
  $prev=[double]$meta.chartPreviousClose
  $dayChg=if($prev){[math]::Round(($price/$prev-1)*100,2)}else{0}
  $avg200=($c|Select-Object -Last 200|Measure-Object -Average).Average
  $vsAvg=($price/$avg200-1)*100
  $ret1y=($c[-1]/$c[0]-1)*100
  $rets=@(); for($i=1;$i -lt $c.Count;$i++){ $rets+=($c[$i]/$c[$i-1]-1) }
  $vol=(Stdev $rets)*[math]::Sqrt(365)*100
  $peak=$c[0];$mdd=0; foreach($p in $c){ if($p -gt $peak){$peak=$p}; $dd=($p/$peak-1)*100; if($dd -lt $mdd){$mdd=$dd} }

  $rsi=RSI $c 14
  $hi52=($c|Measure-Object -Maximum).Maximum
  $lo52=($c|Measure-Object -Minimum).Minimum
  $fromHigh=[math]::Round(($price/$hi52-1)*100,1)
  $rangePos=if($hi52 -ne $lo52){[math]::Round(($price-$lo52)/($hi52-$lo52)*100,0)}else{50}
  $w20=$c|Select-Object -Last 20
  $sma20=($w20|Measure-Object -Average).Average
  $sd20=Stdev $w20
  $bollB=if($sd20 -gt 0){[math]::Round(($price-($sma20-2*$sd20))/(4*$sd20)*100,0)}else{50}

  $sTrend=Clamp(50+$vsAvg*2.5)
  $sMom=Clamp(50+$ret1y*1.6)
  $sStab=Clamp(100-($vol-15)*2)
  $sDD=Clamp(100+($mdd+10)*2)
  $score=[math]::Round(($sTrend+$sMom+$sStab+$sDD)/4)

  $step=[math]::Max(1,[math]::Floor($c.Count/52))
  $spark=@(); for($i=0;$i -lt $c.Count;$i+=$step){ $spark+=[math]::Round($c[$i],4) }

  $priceRound = if($price -ge 1){ [math]::Round($price,2) } else { [math]::Round($price,4) }
  $results += [ordered]@{
    sym=$sym; name=$meta.longName; price=$priceRound; dayChg=$dayChg;
    ret1y=[math]::Round($ret1y,1); vsAvg=[math]::Round($vsAvg,1); vol=[math]::Round($vol,0); mdd=[math]::Round($mdd,0);
    sTrend=$sTrend; sMom=$sMom; sStab=$sStab; sDD=$sDD; score=$score; spark=$spark;
    rsi=$rsi; fromHigh=$fromHigh; rangePos=$rangePos; bollB=$bollB
  }
  Write-Host ("  {0,-9} `${1,-10} {2,6:N1}%/1yr  score {3}/100" -f $sym,$priceRound,$ret1y,$score) -ForegroundColor Green
}

$today=(Get-Date).ToString("yyyy-MM-dd HH:mm")
$json=($results | ConvertTo-Json -Depth 5 -Compress)
"window.AEGIS_CRYPTO = { updated: `"$today`", coins: $json };" | Out-File "$PSScriptRoot\crypto.js" -Encoding utf8
Write-Host "`nSaved crypto.js  ($($results.Count) coins, $today)" -ForegroundColor Cyan