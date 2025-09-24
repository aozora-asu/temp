param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$Message
)

Add-Type -AssemblyName PresentationFramework

# WPFウィンドウ定義
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="$Title"
        Width="500"
        SizeToContent="Height"
        WindowStartupLocation="Manual"
        Topmost="True" ResizeMode="NoResize"
        WindowStyle="ToolWindow" Background="LightYellow" Opacity="0.95">
    <Border CornerRadius="8" BorderBrush="Gray" BorderThickness="1" Padding="10">
        <StackPanel>
            <TextBlock Name="TitleText" FontSize="18" FontWeight="Bold" Margin="0,0,0,10"/>
            <TextBlock Name="MessageText" FontSize="14" TextWrapping="Wrap"/>
        </StackPanel>
    </Border>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# テキスト代入
$window.FindName("TitleText").Text   = $Title
$window.FindName("MessageText").Text = $Message

# 画面サイズ
$screenWidth  = [System.Windows.SystemParameters]::PrimaryScreenWidth
$screenHeight = [System.Windows.SystemParameters]::PrimaryScreenHeight
$margin = 20

# 表示前に Loaded イベントで位置を調整する
# 表示前に Loaded イベントで位置を調整 + 音再生
# 表示前に Loaded イベントで位置を調整 + 音再生
$window.add_Loaded({
    $window.UpdateLayout()

    $window.Left = $screenWidth - $window.ActualWidth - $margin
    $topPos = $screenHeight - $window.ActualHeight - $margin
    if ($topPos -lt 0) { $topPos = 0 }
    $window.Top = $topPos

    # === サウンドを鳴らす（Asterisk に変更） ===
    # === サウンドを鳴らす（標準wavを直接再生） ===
Add-Type -AssemblyName PresentationCore

$media = New-Object System.Windows.Media.MediaPlayer
$media.Open([uri]"C:\Windows\Media\Windows Exclamation.wav")
$media.Volume = 1.0   # 0.0 ～ 1.0 (最大)
$media.Play()


})



# タイマー：10秒後に自動で閉じる
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(10)
$timer.Add_Tick({ $window.Close() })
$timer.Start()

$window.ShowDialog() | Out-Null
