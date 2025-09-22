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
if(-not $div){ return }   # 通知しないで終了

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
  $detailUrl = if($href -like "http*"){ $href } else { $base + $href }

  $status = $tds.item(1).innerText.Trim()
  $info   = $tds.item(2).innerText.Trim()

  if($status -in @("運転見合わせ","運転再開")){
    # 詳細ページ
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

if ($result.Count -gt 0) {
    # ステータスごとにまとめて通知
    $groups = $result | Group-Object 状況
    foreach ($g in $groups) {
        $msgs = @()
        foreach ($r in $g.Group) {
            $msgs += "路線: $($r.路線)`n詳細: $($r.詳細)`n運転計画: $($r.運転計画)"
            $msgs += "" # 空行
        }
        $title = "$($g.Name) 情報"
        $message = $msgs -join "`n"
        powershell -ExecutionPolicy Bypass -File "$PSScriptRoot/notify.ps1" -Title $title -Message $message
    }
}
