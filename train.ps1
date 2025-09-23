param(
  [string]$Url = "https://transit.yahoo.co.jp/diainfo/area/4",
  [int]$TimeoutSec = 30
)

function Get-Page($u,$t){
  try {
    Invoke-WebRequest -Uri $u -TimeoutSec $t -ErrorAction Stop
  } catch {
    Write-Warning "GET失敗: $u"
    return $null
  }
}

# 一覧ページ
$resp = Get-Page $Url $TimeoutSec
if(-not $resp){ return }

$doc = $resp.ParsedHtml
$div = $doc.getElementById("mdStatusTroubleLine")
if(-not $div){ return }   # 異常なし → 通知せず終了

# <tr>ごとに処理
$trs = $div.getElementsByTagName("tr")
$result = @()
$base = "https://transit.yahoo.co.jp"

foreach($tr in $trs){
  $tds = $tr.getElementsByTagName("td")
  if($tds.length -lt 3){ continue }

  $lineNode = $tds.item(0).getElementsByTagName("a") | Select-Object -First 1
  if(-not $lineNode){ continue }

  $lineName  = $lineNode.innerText.Trim()
  $href      = $lineNode.href

  # URL補正（about:/... を除去して正しいURLにする）
  if ($href -like "http*") {
    $detailUrl = $href
  }
  elseif ($href.StartsWith("/")) {
    $detailUrl = $base + $href
  }
  else {
    $detailUrl = $base + ($href -replace "^about:","")
  }

  $status = $tds.item(1).innerText.Trim()

  if($status -in @("運転見合わせ","運転再開")){
    # 詳細ページから運転計画を取得
    $plan = $null
    $subResp = Get-Page $detailUrl $TimeoutSec
    if($subResp){
      try {
        $subDoc = $subResp.ParsedHtml
        $svcDiv = $subDoc.getElementById("mdServiceStatus")
        if($svcDiv){
          $dds = $svcDiv.getElementsByTagName("dd")
          $planTexts = @()
          foreach($dd in $dds){
            $txt = $dd.innerText.Trim()
            if ($txt) { $planTexts += $txt }
          }
          if ($planTexts.Count -gt 0) {
            $plan = ($planTexts -join " / ")
          }
        }
      } catch {
        # fallback: 正規表現でHTMLから抜き出す
        $html = $subResp.Content
        $matches = [regex]::Matches($html, '<dd[^>]*>(.*?)</dd>', 'Singleline')
        $planTexts = @()
        foreach ($m in $matches) {
          $t = ($m.Groups[1].Value -replace '<.*?>','').Trim()
          if ($t) { $planTexts += $t }
        }
        if ($planTexts.Count -gt 0) {
          $plan = ($planTexts -join " / ")
        }
      }
    }

    $result += [pscustomobject]@{
      路線     = $lineName
      状況     = $status
      詳細     = $plan
      URL      = $detailUrl
    }
  }
}

# === 通知済み状態の管理 ===
$stateFile = Join-Path $PSScriptRoot "last_state.json"
$prevState = @{}

if (Test-Path $stateFile) {
    try {
        $json = Get-Content $stateFile -Raw | ConvertFrom-Json
        foreach ($prop in $json.PSObject.Properties) {
            $prevState[$prop.Name] = $prop.Value
        }
    } catch { $prevState = @{} }
}

$changed = @()

foreach ($r in $result) {
    $key = $r.路線
    $value = "$($r.状況):$($r.詳細)"

    if (-not $prevState.ContainsKey($key) -or $prevState[$key] -ne $value) {
        # 前回と違う場合のみ通知対象に追加
        $changed += $r
        # 状態を更新
        $prevState[$key] = $value
    }
}

# === 通知 ===
if ($changed.Count -gt 0) {
    $groups = $changed | Group-Object 状況
    foreach ($g in $groups) {
        $msgs = @()
        foreach ($r in $g.Group) {
            $msgs += "路線: $($r.路線)`n詳細: $($r.詳細)"
            $msgs += "" # 空行
        }
        $title = "$($g.Name) 情報"
        $message = $msgs -join "`n"
        & "$PSScriptRoot/notify.ps1" -Title $title -Message $message
    }

    # 状態を保存
    $prevState | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
}
