# Aegis - pulls company fundamentals (P/E, margins, growth, dividend) -> fundamentals.js
# Uses Yahoo's cookie+crumb handshake. No account or API key needed.

$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
# Yahoo cookie+crumb handshake. fc.yahoo.com is defunct; finance.yahoo.com now sets
# no cookies on its own - the usable session cookies come from the consent domain
# (guce.yahoo.com), and the crumb from query1. Without this the crumb call 401s.
$null = Invoke-WebRequest "https://finance.yahoo.com" -UserAgent $ua -SessionVariable sess -UseBasicParsing -TimeoutSec 15 -ErrorAction SilentlyContinue
try { $null = Invoke-WebRequest "https://guce.yahoo.com/consent" -UserAgent $ua -WebSession $sess -UseBasicParsing -TimeoutSec 15 -ErrorAction SilentlyContinue } catch {}
$crumb=$null
foreach($h in @("query1.finance.yahoo.com","query2.finance.yahoo.com")){
  try {
    $c=(Invoke-WebRequest "https://$h/v1/test/getcrumb" -UserAgent $ua -WebSession $sess -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop).Content
    if($c -and $c.Length -lt 40){ $crumb=$c; break }
  } catch {}
}
if(-not $crumb){ Write-Host "Could not get crumb - fundamentals unavailable right now." -ForegroundColor Yellow; exit }

function Rw($node){ if($node -and $node.PSObject.Properties['raw']){ return $node.raw } return $null }
function Pct($v){ if($null -eq $v){return $null} return [math]::Round($v*100,1) }
function Rnd($v,$d){ if($null -eq $v){return $null} return [math]::Round($v,$d) }

$symbols = Get-Content "$PSScriptRoot\watchlist.txt" | ForEach-Object { $_.Trim().ToUpper() } | Where-Object { $_ -and $_ -notmatch '^#' }
$results=@()

foreach($sym in $symbols){
  try {
    $u="https://query1.finance.yahoo.com/v10/finance/quoteSummary/$sym`?modules=summaryDetail,defaultKeyStatistics,financialData&crumb=$([uri]::EscapeDataString($crumb))"
    $r=Invoke-RestMethod $u -UserAgent $ua -WebSession $sess -TimeoutSec 15
    $res=$r.quoteSummary.result[0]; $sd=$res.summaryDetail; $ks=$res.defaultKeyStatistics; $fd=$res.financialData
    $div = Rw $sd.dividendYield; if($null -eq $div){ $div = Rw $sd.trailingAnnualDividendYield }
    $results += [ordered]@{
      sym=$sym
      pe=Rnd (Rw $sd.trailingPE) 1
      fwdPe=Rnd (Rw $sd.forwardPE) 1
      pb=Rnd (Rw $ks.priceToBook) 1
      margin=Pct (Rw $fd.profitMargins)
      revGrowth=Pct (Rw $fd.revenueGrowth)
      roe=Pct (Rw $fd.returnOnEquity)
      divYield=Pct $div
      debtEq=Rnd (Rw $fd.debtToEquity) 0
      mktCap=[math]::Round((Rw $sd.marketCap)/1e9,1)
      rec=$fd.recommendationKey
    }
    Write-Host ("  {0,-6} P/E {1,6}  margin {2,5}%  growth {3,5}%  div {4,4}%" -f $sym,(Rw $sd.trailingPE),(Pct (Rw $fd.profitMargins)),(Pct (Rw $fd.revenueGrowth)),(Pct $div)) -ForegroundColor Green
  } catch {
    Write-Host ("  {0,-6} no fundamentals" -f $sym) -ForegroundColor Yellow
  }
  Start-Sleep -Milliseconds 200
}

$today=(Get-Date).ToString("yyyy-MM-dd HH:mm")
$json=($results | ConvertTo-Json -Depth 4 -Compress)
"window.STEADY_FUND = { updated: `"$today`", fundamentals: $json };" | Out-File "$PSScriptRoot\fundamentals.js" -Encoding utf8
Write-Host "`nSaved fundamentals.js  ($($results.Count) stocks, $today)" -ForegroundColor Cyan