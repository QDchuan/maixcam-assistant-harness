' MaixCAM Assistant - launcher
'
' Double-clicking the desktop / Start Menu shortcut runs this file.
'
' Why VBS instead of .cmd: a .cmd leaves a black console window sitting
' there and the user cannot tell whether it is safe to close. WScript.Shell
' Run(..., 0, False) hides the window (0) and does not wait (False), so a
' double-click only opens the browser.
'
' To stop the app: end node.exe in Task Manager.

Option Explicit

Dim fso, shell, scriptDir, appRoot, dshHome, cmd

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

' This file lives in <repo root>\maixcam\, so the root is one level up.
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
appRoot = fso.GetParentFolderName(scriptDir)

If Not fso.FileExists(appRoot & "\apps\cli\lib\bin.js") Then
  MsgBox "Built app not found:" & vbCrLf & appRoot & "\apps\cli\lib\bin.js" & vbCrLf & vbCrLf & _
         "Run setup.cmd first to install and build.", 16, "MaixCAM Assistant"
  WScript.Quit 1
End If

' The app uses its OWN dsh home, independent of any other install here.
dshHome = shell.ExpandEnvironmentStrings("%USERPROFILE%") & "\.dsh-maixcam"

cmd = "cmd /c set ""DSH_HOME=" & dshHome & """ && cd /d """ & appRoot & """ && node apps\cli\lib\bin.js --profile maixcam --patch maixcam\app.patch.yml --port 8890"

' 0 = hidden window, False = do not wait.
shell.Run cmd, 0, False