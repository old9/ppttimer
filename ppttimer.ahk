#SingleInstance force
#NoTrayIcon

pt_IniFile := A_ScriptDir "\ppttimer.ini"

iniread, startKey, %pt_IniFile%, shortcuts, startKey, F12
iniread, stopKey, %pt_IniFile%, shortcuts, stopKey, ^F12
iniread, quitKey, %pt_IniFile%, shortcuts, quitKey, #ESC

iniread, opacity, %pt_IniFile%, main, opacity, 180
iniread, fontface, %pt_IniFile%, main, fontface, 寰蒋闆呴粦
iniread, fontweight, %pt_IniFile%, main, fontweight, bold
iniread, fontsize, %pt_IniFile%, main, fontsize, 40

iniread, textColor, %pt_IniFile%, main, textcolor, 000000
iniread, AheadColor, %pt_IniFile%, main, aheadColor, 9D1000
iniread, timeoutColor, %pt_IniFile%, main, timeoutColor, FF0000
iniread, backgroundColor, %pt_IniFile%, main, backgroundColor, FFFFAA

iniread, bannerWidth, %pt_IniFile%, main, width, 300
iniread, bannerHeight, %pt_IniFile%, main, height, 70


hotkey, %startKey%, startIt
hotkey, %stopKey%, stopIt
hotkey, %quitKey%, quitIt

resetTimer()

Gui, Font, %fontweight% s%fontsize% c%textColor% textcenter, %fontface%
Gui, Font, c%textColor%
Gui, Color, %backgroundColor%
Gui Add, Text, x0 y0 h%bannerHeight% w%bannerWidth% vpt_DurationText
guicontrol, +0x200 +center, pt_DurationText
GuiControl,, pt_DurationText, % FormatSeconds(pt_Duration)
GuiControl, Font, pt_DurationText
xposition := A_ScreenWidth - bannerWidth
Gui +LastFound +ToolWindow +AlwaysOnTop -Caption
Gui Show, y0 h%bannerHeight% w%bannerWidth% x%xposition% , CountDown
winset,transparent, %opacity%, CountDown
Winset, ExStyle, +0x20, CountDown
pt_Gui := WinExist()  ; Remember Gui window ID
isPptTimerOn := false
;isTimerOn := false
SetTimer, checkPowerpoint, 250
Return



;;; if winexsist powerpoint presetation, auto start
startTimer(){
  global pt_Duration
  global pt_DurationText
  global CountDownTimer
  SetTimer CountDownTimer, Off
  GuiControl,, pt_DurationText, % FormatSeconds(pt_Duration)
  SetTimer CountDownTimer, 1000
  SetTimer CountDownTimer, on
}

resetTimer(){
  global pt_Duration
  global pt_PlayFinishSound
  global pt_FinishSoundFile
  global pt_PlayWarningSound
  global pt_WarningSoundFile
  global pt_Ahead
  global pt_IniFile
  global textColor
  global backgroundColor

  Gui, Font, c%textColor%
  gui, color, %backgroundColor%

  GuiControl, font, pt_DurationText
  IniRead, pt_Duration, %pt_IniFile%, Main, Duration, % 5*60
  IniRead, pt_PlayFinishSound, %pt_IniFile%, Main, PlayFinishSound, %True%
  IniRead, pt_FinishSoundFile, %pt_IniFile%, Main, FinishSoundFile, %A_ScriptDir%\
  IniRead, pt_PlayWarningSound, %pt_IniFile%, Main, PlayWarningSound, %True%
  IniRead, pt_WarningSoundFile, %pt_IniFile%, Main, WarningSoundFile, %A_ScriptDir%\
  IniRead, pt_Ahead, %pt_IniFile%, Main, Ahead, 120
  ;msgbox, % pt_Duration " " pt_Ahead
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


/*
windIDd := WinExist("My Window")
isFullScreen := isWindowFullScreen(windIDd)
MsgBox %isFullScreen%
Return


isWindowFullScreen(WinID)
{
    ;checks if the specified window is full screen
    ;use WinExist of another means to get the Unique ID (HWND) of the desired window

    if ( !WinID )
        return

    WinGet, style, Style, ahk_id %WinID%
    ; 0x800000 is WS_BORDER.
    ; 0x20000000 is WS_MINIMIZE.
    ; no border and not minimized
    retVal := (style & 0x20800000) ? 0 : 1
    Return, retVal
}
*/
/*
checkPdf:
IfWinExist, ahk_class AcrobatSDIWindow
{

    WinGet, style, Style, A
    ; 0x800000 is WS_BORDER.
    ; 0x20000000 is WS_MINIMIZE.
    ; no border and not minimized
    retVal := (style & 0x20800000) ? 0 : 1
}
else
{
}
return

 */




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
Return

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
  ;return NumberOfSeconds//3600 ":" mmss  ; This method is used to support more than 24 hours worth of sections.
  return mmss  ; This method is used to support more than 24 hours worth of sections.
}

GuiClose:
  ExitApp
Return
