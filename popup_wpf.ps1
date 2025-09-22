Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="運行情報" Height="200" Width="400"
        WindowStartupLocation="CenterScreen"
        Topmost="True" Background="LightYellow"
        ResizeMode="NoResize" WindowStyle="ToolWindow">
    <StackPanel VerticalAlignment="Center" Margin="20">
        <TextBlock Name="MsgText" Text="通知内容" FontSize="16" TextWrapping="Wrap" Margin="0,0,0,20"/>
        <Button Name="OkButton" Content="閉じる" Width="80" Height="30" HorizontalAlignment="Center"/>
    </StackPanel>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# メッセージ差し替え
$window.FindName("MsgText").Text = $Message

# ボタンイベント
$ok = $window.FindName("OkButton")
$ok.Add_Click({ $window.Close() })

$window.ShowDialog() | Out-Null