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

iniread, manualModeSupressDetection, %pt_IniFile%, main, manualModeSupressDetection, 1

; Hotkeys
hotkey, %startKey%, manuallyStart
hotkey, %stopKey%, stopIt
hotkey, %quitKey%, quitIt
hotkey, %moveKey%, moveToNextMonitor

DPI_F := A_ScreenDPI / 96
fontsize := fontsize / DPI_F

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
manualMode := false
SetTimer, checkFullscreenWindow, 250
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
  SysGet, MonitorCount, MonitorCount
  if (monitorIndex > MonitorCount || MonitorCount < 1) {
    monitorIndex := 1
  }
  ; Retrieve monitor dimensions using SysGet
  SysGet, MonitorName, MonitorName, %monitorIndex%
  SysGet, Monitor, Monitor, %monitorIndex%
  SysGet, MonitorWorkArea, MonitorWorkArea, %monitorIndex%

  MonitorWidth := MonitorRight - MonitorLeft
  ; Calculate the new position
  xposition := MonitorLeft + (MonitorWidth - bannerWidth)
  Gui Show, x%xposition% y%monitorTop% w%bannerWidth% h%bannerHeight%, CountDown
}



startTimer() {
  global pt_Duration, pt_DurationText, startTime
  SetTimer CountDownTimer, Off
  startTime := A_TickCount
  GuiControl,, pt_DurationText, % FormatSeconds(pt_Duration)
  SetTimer CountDownTimer, 250
  SetTimer CountDownTimer, on
}

resetTimer() {
  global pt_Duration, pt_PlayFinishSound, pt_FinishSoundFile, pt_PlayWarningSound, pt_WarningSoundFile, pt_Ahead, pt_IniFile, textColor, backgroundColor, manualMode

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

;start manually
manuallyStart:
manualMode := true
Gosub startIt
return

;restart
startIt:
resetTimer()
startTimer()
return

stopIt:
resetTimer()
manualMode := false
SetTimer CountDownTimer, off
return

quitIt:
IniWrite, %lastMonitor%, %pt_IniFile%, main, lastMonitor
ExitApp
return

checkFullscreenWindow:
if (!manualMode || !manualModeSupressDetection) {
  if (isAnyFullscreenWindow()) {
    if !isPptTimerOn {
      isPptTimerOn := true
      resetTimer()
      startTimer()
    }
  } else {
    if isPptTimerOn {
      isPptTimerOn := false
      resetTimer()
      SetTimer CountDownTimer, off
    }
  }
}
return


isAnyFullscreenWindow() {
  ; Get the number of monitors
  SysGet, MonitorCount, MonitorCount

  ; Get the list of all windows
  WinGet, winList, List
  Loop, %winList%
  {
    winID := winList%A_Index%
    ; Get window style and position
    WinGet, winStyle, Style, ahk_id %winID%
    WinGetPos, winX, winY, winWidth, winHeight, ahk_id %winID%

    ; Check if the window is visible
    WinGet, winState, MinMax, ahk_id %winID%
    if (winState = -1) ; Skip invisible windows
      continue
    WinGetTitle, winTitle, ahk_id %winID%
    WinGetClass, winClass, ahk_id %winID%
    if (winClass = "Progman" || winClass = "WorkerW" || winClass = "TscShellContainerClass") ; Exclude desktop and similar windows
      continue
    if (winTitle = "") ; Exclude windows with no title (often background/system windows)
      continue

    ; Loop through all monitors to check for fullscreen
    Loop, %MonitorCount%
    {
      monitorIndex := A_Index
      ; Get monitor dimensions
      SysGet, Monitor, Monitor, %monitorIndex%

      MonitorWidth := MonitorRight - MonitorLeft
      MonitorHeight := MonitorBottom - MonitorTop

      ; Check if the window matches the monitor's dimensions and is borderless
      isFullscreen := ((winStyle & 0x20800000) = 0) ; No border, not minimized
      isFullscreen := isFullscreen && (winX = monitorLeft && winY = monitorTop) ; Top-left corner of the monitor
      isFullscreen := isFullscreen && (winWidth = monitorWidth && winHeight = monitorHeight) ; Covers the monitor

      if (isFullscreen) {
        return true ; A fullscreen window is found
      }
    }
  }
  return false ; No fullscreen window found
}

updateCountDownText(){
  global pt_PlayFinishSound, pt_PlayWarningSound, remaining, timeoutColor, backgroundColor, AheadColor, textColor, pt_Ahead, blink
  if (remaining < 0){
    blink := !blink
    if (blink) {
      Gui, Font, c%timeoutColor%
      gui, color, %backgroundColor%
    } else {
      Gui, Font, c%backgroundColor%
      gui, color, %timeoutColor%
    }
  } else if (remaining <= pt_Ahead) {
    if (remaining = pt_Ahead && pt_PlayWarningSound){
      Gosub PlayWarningSound
    }
    Gui, Font, c%AheadColor%
  } else {
    Gui, Font, c%textColor%
  }
  GuiControl,, pt_DurationText, % FormatSeconds(remaining)
  GuiControl, Font, pt_DurationText
  if (remaining = 0 && pt_PlayFinishSound){
    Gosub PlayFinishSound
  }
}

CountDownTimer(){
  global pt_Duration, startTime, remaining

  elapsed := (A_TickCount - startTime) // 1000
  if (remaining != pt_Duration - elapsed) {
    remaining := pt_Duration - elapsed
    updateCountDownText()
  }
}

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
  if (NumberOfSeconds < 0){
    revert := "+"
    NumberOfSeconds := -NumberOfSeconds
  }
  time += %NumberOfSeconds%, seconds
  FormatTime, mmss, %time%, mm:ss
  return revert mmss
}

GuiClose:
IniWrite, %lastMonitor%, %pt_IniFile%, main, lastMonitor
ExitApp
return
