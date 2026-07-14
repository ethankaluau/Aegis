# Aegis — refreshes real fund data into funds.js
# Pulls from Yahoo Finance. No account or API key needed.

$funds = @(
  @{name="S&P 500";         sym="SPY"; fee=0.09; plan=7; desc="The 500 biggest US companies, in one fund."},
  @{name="Total US Market"; sym="VTI"; fee=0.03; plan=7; desc="Almost every US company at once. Very diversified."},
  @{name="Total World";     sym="VT";  fee=0.07; plan=7; desc="US plus the rest of the world. The whole planet."},
  @{name="US Bonds";        sym="BND"; fee=0.03; plan=3; desc="Loans to gov't & companies. Calmer, lower growth."}
)

$results = @()
foreach ($f in $funds) {
  try {
    $u = "https://query2.finance.yahoo.com/v8/finance/chart/$($f.sym)?range=10y&interval=1mo"
    $r = Invoke-RestMethod $u -Headers @{ "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
    $res=$r.chart.result[0]; $ts=$res.timestamp; $c=$res.indicators.adjclose[0].adjclose
    $i0=0; while($null -eq $c[$i0]){$i0++}; $i1=$c.Count-1; while($null -eq $c[$i1]){$i1--}
    $fd=[datetimeoffset]::FromUnixTimeSeconds($ts[$i0]).DateTime
    $ld=[datetimeoffset]::FromUnixTimeSeconds($ts[$i1]).DateTime
    $yrs=($ld-$fd).Days/365.25
    $cagr=[math]::Round((([math]::Pow($c[$i1]/$c[$i0],1/$yrs)-1)*100),1)
    $worst=0; for($k=$i0+1;$k -le $i1;$k++){ if($c[$k] -and $c[$k-1]){ $d=($c[$k]/$c[$k-1]-1)*100; if($d -lt $worst){$worst=$d} } }
    $results += @{ name=$f.name; sym=$f.sym; desc=$f.desc; fee=$f.fee; plan=$f.plan;
                   recent=$cagr; worst=[math]::Round($worst,0); years=[math]::Round($yrs,0) }
    Write-Host ("  {0,-16} {1}  {2,5:N1}%/yr  (ok)" -f $f.name,$f.sym,$cagr) -ForegroundColor Green
  } catch {
    Write-Host ("  {0,-16} {1}  FETCH FAILED - keeping old number if any" -f $f.name,$f.sym) -ForegroundColor Yellow
  }
}

$today = (Get-Date).ToString("yyyy-MM-dd")
$json = ($results | ConvertTo-Json -Depth 4 -Compress)
$body = "window.STEADY_DATA = { updated: `"$today`", funds: $json };"
$body | Out-File -FilePath "$PSScriptRoot\funds.js" -Encoding utf8
Write-Host "`nSaved funds.js  (updated $today)" -ForegroundColor Cyan