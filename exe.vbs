On Error Resume Next   ' エラーハンドリングを有効化

Dim objShell, ret
Set objShell = CreateObject("WScript.Shell")

' PowerShell メインスクリプトを起動
ret = objShell.Run("powershell.exe -ExecutionPolicy Bypass -NoProfile -File "".\main.ps1""", 0, False)

' 起動に失敗した場合の処理
If Err.Number <> 0 Then
    ' ログ出力（.vbs と同じフォルダに error.log を作成）
    Dim fso, logfile, ts
    Set fso = CreateObject("Scripting.FileSystemObject")
    logfile = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "error.log")
    Set ts = fso.OpenTextFile(logfile, 8, True)  ' 8=追記モード
    ts.WriteLine Now & " [VBScript ERROR] " & Err.Description
    ts.Close

    ' ユーザーにエラーダイアログ
    MsgBox "エラーが起きたため強制終了しました。もう一度お試しください。" & vbCrLf & _
           "詳細: " & Err.Description, _
           vbCritical, "電車・気象情報・停電情報チェッカー"

    ' 終了コードを異常終了にして終了
    WScript.Quit 1
End If

On Error GoTo 0   ' エラーハンドリング解除
