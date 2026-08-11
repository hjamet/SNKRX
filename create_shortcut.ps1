$WshShell = New-Object -ComObject WScript.Shell
$DesktopPath = [System.Environment]::GetFolderPath('Desktop')
$ShortcutPath = Join-Path -Path $DesktopPath -ChildPath "SNKRX (Modded).lnk"
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "C:\Users\Jamet\Documents\code\SNKRX\run_snkrx_mod.bat"
$Shortcut.WorkingDirectory = "C:\Users\Jamet\Documents\code\SNKRX"
$Shortcut.Description = "SNKRX Modded Launcher"
if (Test-Path "C:\Users\Jamet\Documents\code\SNKRX\bin\love\game.ico") {
    $Shortcut.IconLocation = "C:\Users\Jamet\Documents\code\SNKRX\bin\love\game.ico"
}
$Shortcut.Save()
Write-Host "Shortcut created at: $ShortcutPath"
