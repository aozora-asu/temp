<#
.SYNOPSIS
  通知を行うラッパースクリプト
.DESCRIPTION
  - Mac では Write-Host で通知内容を標準出力
  - Windows では popup.ps1 を呼び出して WPF 通知を表示
.PARAMETER Title
  通知のタイトル
.PARAMETER Message
  通知の本文（複数行可）
.EXAMPLE
  .\notify.ps1 -Title "運行情報" -Message "山手線 運転見合わせ"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$Message
)

if ($IsWindows) {
    # Windowsの場合 → popup.ps1に処理を渡す
    $popupScript = Join-Path $PSScriptRoot "popup.ps1"
    if (Test-Path $popupScript) {
        & powershell -ExecutionPolicy Bypass -File $popupScript -Title $Title -Message $Message
    }
    else {
        Write-Warning "popup.ps1 が見つかりません: $popupScript"
    }
}
elseif ($IsMacOS) {
    # Macの場合 → 標準出力で代用
    Write-Host "==== 通知 ===="
    Write-Host "[$Title]"
    Write-Host $Message
    Write-Host "==============="
}
else {
    # Linuxその他
    Write-Host "[$Title] $Message (通知未対応OS)"
}