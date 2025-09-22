param(
    [string]$Title = "通知",
    [string[]]$Message,
    [string]$Sound = "Asterisk"  # 既定の音
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- 音を鳴らす ---
switch ($Sound) {
    "Asterisk"    { [System.Media.SystemSounds]::Asterisk.Play() }
    "Beep"        { [System.Media.SystemSounds]::Beep.Play() }
    "Exclamation" { [System.Media.SystemSounds]::Exclamation.Play() }
    "Hand"        { [System.Media.SystemSounds]::Hand.Play() }
    "Question"    { [System.Media.SystemSounds]::Question.Play() }
    default {
        if (Test-Path $Sound) {
            $player = New-Object System.Media.SoundPlayer $Sound
            $player.Play()
        }
    }
}

# --- フォーム処理（前と同じ） ---
$form = New-Object Windows.Forms.Form
$form.Text = $Title
$form.Size = New-Object Drawing.Size(500,300)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

$label = New-Object Windows.Forms.Label
if ($Message -is [string[]]) {
    $label.Text = ($Message -join "`r`n")
} else {
    $label.Text = $Message
}
$label.AutoSize = $true
$label.Location = New-Object Drawing.Point(20,20)
$label.Font = New-Object Drawing.Font("Meiryo",11,[Drawing.FontStyle]::Regular)

$panel = New-Object Windows.Forms.Panel
$panel.Size = New-Object Drawing.Size(450,180)
$panel.Location = New-Object Drawing.Point(20,20)
$panel.AutoScroll = $true
$panel.Controls.Add($label)
$form.Controls.Add($panel)

$button = New-Object Windows.Forms.Button
$button.Text = "閉じる"
$button.Location = New-Object Drawing.Point(200,220)
$button.Add_Click({ $form.Close() })
$form.Controls.Add($button)

$form.ShowDialog()