#SingleInstance force
#NoTrayIcon

pt_IniFile := A_ScriptDir "\ppttimer.ini"

; Read settings from the INI file
iniread, startKey, %pt_IniFile%, shortcuts, startKey, F12
iniread, stopKey, %pt_IniFile%, shortcuts, stopKey, ^F12
iniread, quitKey, %pt_IniFile%, shortcuts, quitKey, #ESC
iniread, moveKey, %pt_IniFile%, shortcuts, moveKey, ^#M

iniread, opacity, %pt_IniFile%, main, opacity, 180
iniread, fontface, %pt_IniFile%, main, fontface, "Microsoft Yahei"
iniread, fontweight, %pt_IniFile%, main, fontweight, bold
iniread, fontsize, %pt_IniFile%, main, fontsize, 40

iniread, textColor, %pt_IniFile%, main, textcolor, 000000
iniread, AheadColor, %pt_IniFile%, main, aheadColor, 9D1000
iniread, timeoutColor, %pt_IniFile%, main, timeoutColor, FF0000
iniread, backgroundColor, %pt_IniFile%, main, backgroundColor, FFFFAA

iniread, bannerWidth, %pt_IniFile%, main, width, 300
iniread, bannerHeight, %pt_IniFile%, main, height, 70
iniread, lastMonitor, %pt_IniFile%, main, lastMonitor, 1

; Hotkeys
hotkey, %startKey%, startIt
hotkey, %stopKey%, stopIt
hotkey, %quitKey%, quitIt
hotkey, %moveKey%, moveToNextMonitor

resetTimer()
Gui, -dpiscale
Gui, +AlwaysOnTop
Gui, Font, %fontweight% s%fontsize% c%textColor% textcenter, %fontface%
Gui, Font, c%textColor%
Gui, Color, %backgroundColor%
Gui Add, Text, x0 y0 h%bannerHeight% w%bannerWidth% vpt_DurationText
guicontrol, +0x200 +center, pt_DurationText
GuiControl,, pt_DurationText, % FormatSeconds(pt_Duration)
GuiControl, Font, pt_DurationText

Gui +LastFound +ToolWindow +AlwaysOnTop -Caption
; Set initial position based on last monitor
MonitorSetup(lastMonitor)
winset, transparent, %opacity%, CountDown
Winset, ExStyle, +0x20, CountDown
pt_Gui := WinExist()  ; Remember Gui window ID
isPptTimerOn := false
SetTimer, checkPowerpoint, 250
Return

; Move Countdown to Next Monitor
moveToNextMonitor:
  SysGet, MonitorCount, MonitorCount
  lastMonitor++
  if (lastMonitor > MonitorCount)
    lastMonitor := 1
  MonitorSetup(lastMonitor)
return


MonitorSetup(monitorIndex) {
  global bannerWidth, bannerHeight
  ; Retrieve monitor dimensions using SysGet
  SysGet, MonitorName, MonitorName, %monitorIndex%
  SysGet, Monitor, Monitor, %monitorIndex%
  SysGet, MonitorWorkArea, MonitorWorkArea, %monitorIndex%

  MonitorWidth := MonitorRight - MonitorLeft
  ; Calculate the new position
  xposition := MonitorLeft + (MonitorWidth - bannerWidth) ; Centered horizontally
  Gui Show, x%xposition% y%monitorTop% w%bannerWidth% h%bannerHeight%, CountDown
}



;;; if winexsist powerpoint presetation, auto start
startTimer() {
  global pt_Duration, pt_DurationText
  SetTimer CountDownTimer, Off
  GuiControl,, pt_DurationText, % FormatSeconds(pt_Duration)
  SetTimer CountDownTimer, 1000
  SetTimer CountDownTimer, on
}

resetTimer() {
  global pt_Duration, pt_PlayFinishSound, pt_FinishSoundFile, pt_PlayWarningSound, pt_WarningSoundFile, pt_Ahead, pt_IniFile, textColor, backgroundColor

  Gui, Font, c%textColor%
  Gui, Color, %backgroundColor%

  GuiControl, font, pt_DurationText
  IniRead, pt_Duration, %pt_IniFile%, Main, Duration, % 5*60
  IniRead, pt_PlayFinishSound, %pt_IniFile%, Main, PlayFinishSound, %True%
  IniRead, pt_FinishSoundFile, %pt_IniFile%, Main, FinishSoundFile, %A_ScriptDir%\
  IniRead, pt_PlayWarningSound, %pt_IniFile%, Main, PlayWarningSound, %True%
  IniRead, pt_WarningSoundFile, %pt_IniFile%, Main, WarningSoundFile, %A_ScriptDir%\
  IniRead, pt_Ahead, %pt_IniFile%, Main, Ahead, 120
  GuiControl,, pt_DurationText, % FormatSeconds(pt_Duration)
}

;restart or start manually
startIt:
resetTimer()
startTimer()
return

stopIt:
resetTimer()
SetTimer CountDownTimer, off
return

quitIt:
IniWrite, %lastMonitor%, %pt_IniFile%, main, lastMonitor
ExitApp
return

checkPowerpoint:
IfWinExist, ahk_class screenClass
{
  if !isPptTimerOn
  {
    isPptTimerOn := true
    resetTimer()
    startTimer()
  }
}
else
{
  if isPptTimerOn
  {
    isPptTimerOn := false
    resetTimer()
    SetTimer CountDownTimer, off
  }
}
return

CountDownTimer:
  Gui +AlwaysOnTop
  pt_Duration--
  if pt_Duration < 0
  {
    blink := !blink
    if blink
    {
      Gui, Font, c%timeoutColor%
      gui, color, %backgroundColor%
    }
    else
    {
      Gui, Font, c%backgroundColor%
      gui, color, %timeoutColor%
    }
    GuiControl,, pt_DurationText, % FormatSeconds(pt_Duration)
  }
  else if (pt_Duration <= pt_Ahead)
  {
    if (pt_Duration = pt_Ahead) && pt_PlayWarningSound
      Gosub PlayWarningSound
    Gui, Font, c%AheadColor%
    GuiControl,, pt_DurationText, % FormatSeconds(pt_Duration)
  }
  else
  {
    Gui, Font, c%textColor%
    GuiControl,, pt_DurationText, % FormatSeconds(pt_Duration)
  }
  GuiControl, font, pt_DurationText
  if pt_Duration = 0
  {
    if pt_PlayFinishSound
      Gosub PlayFinishSound
  }
  SetTimer CountDownTimer, 1000
Return

PlayFinishSound:
  IfExist %pt_FinishSoundFile%
    SoundPlay %pt_FinishSoundFile%
return

PlayWarningSound:
  IfExist %pt_WarningSoundFile%
    SoundPlay %pt_WarningSoundFile%
Return

FormatSeconds(NumberOfSeconds)  ; Convert the specified number of seconds to hh:mm:ss format.
{
  time = 19990101  ; *Midnight* of an arbitrary date.
  if NumberOfSeconds < 0
    NumberOfSeconds := -NumberOfSeconds
  time += %NumberOfSeconds%, seconds
  FormatTime, mmss, %time%, mm:ss
  return mmss
}

GuiClose:
IniWrite, %lastMonitor%, %pt_IniFile%, main, lastMonitor
ExitApp
return
