# train.ps1
# Yahoo! 路線情報: 運転見合わせ/再開の路線を抽出し、詳細ページから運転計画を取得
# DOM型 (ParsedHtml) を利用

param(
  [string]$Url = "https://transit.yahoo.co.jp/diainfo/area/4",
  [int]$TimeoutSec = 30
)

# メッセージボックス用に Forms をロード
Add-Type -AssemblyName System.Windows.Forms

function Get-Page($u,$t){
  try {
    Invoke-WebRequest -Uri $u -TimeoutSec $t -ErrorAction Stop
  } catch {
    Write-Warning "GET失敗: $u"
    return $null
  }
}

# ① 一覧ページ
$resp = Get-Page $Url $TimeoutSec
if(-not $resp){ return }

$doc = $resp.ParsedHtml
$div = $doc.getElementById("mdStatusTroubleLine")

if(-not $div){
  [System.Windows.Forms.MessageBox]::Show(
    "現在、すべての電車は通常通り運行しています",
    "【運行情報】",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
  )
  return
}

# ② <tr>ごとに処理
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
  $detailUrl = if($href -like "http*"){ $href } else { $base + $href }

  $status = $tds.item(1).innerText.Trim()
  $info   = $tds.item(2).innerText.Trim()

  if($status -in @("運転見合わせ","運転再開")){
    # ③ 詳細ページへアクセス
    $plan = $null
    $subResp = Get-Page $detailUrl $TimeoutSec
    if($subResp){
      $subDoc = $subResp.ParsedHtml
      $svcDiv = $subDoc.getElementById("mdServiceStatus")
      if($svcDiv){
        $dds = $svcDiv.getElementsByTagName("dd")
        foreach($dd in $dds){
          if($dd.className -eq "trouble"){
            $plan = $dd.innerText.Trim()
          }
        }
      }
    }

    $result += [pscustomobject]@{
      路線     = $lineName
      状況     = $status
      詳細     = $info
      URL      = $detailUrl
      運転計画 = $plan
    }
  }
}

if ($result.Count -eq 0) {
    powershell -ExecutionPolicy Bypass -File ".\popup.ps1" `
      -Title "運行情報" -Message "現在、運転見合わせ/運転再開の路線はありません"
}
else {
    $msgs = @()
    foreach ($r in $result) {
        $msgs += "路線: $($r.路線)`n状況: $($r.状況)`n詳細: $($r.詳細)`n運転計画: $($r.運転計画)"
        $msgs += "" # 空行で区切り
    }
    powershell -ExecutionPolicy Bypass -File ".\popup.ps1" `
      -Title "運行情報" -Message $msgs
}