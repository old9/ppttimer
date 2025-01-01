#Persistent
#SingleInstance force

DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

global pt_IniFile := A_ScriptDir "\ppttimer.ini"
global lastProfile, profiles := [], MonitorCount, lastMonitor, manualModeSupressDetection, showOnAllMonitors, isPptTimerOn
global startKey, stopKey, quitKey, moveKey, allMonitorKey
global opacity, fontface, fontweight, fontsize, textColor, AheadColor, timeoutColor, backgroundColor, bannerWidth, bannerHeight, pt_Duration, pt_PlayFinishSound, pt_FinishSoundFile, pt_PlayWarningSound, pt_WarningSoundFile, pt_Ahead

global Guis := []
global Texts := []

SysGet, MonitorCount, MonitorCount
Loop, %MonitorCount% {
  Gui, New, +HwndhCountDown
  Gui, -DPIScale +AlwaysOnTop +LastFound +ToolWindow -Caption
  Gui Add, Text, x0 y0 HwndhDurationText
  GuiControl, +0x200 +center, %hDurationText%
  Winset, ExStyle, +0x20
  Guis.push(hCountDown)
  Texts.push(hDurationText)
}

loadSettings()
creatMenus()

isPptTimerOn := false

resetTimer()

SetTimer, checkFullscreenWindow, 250

return






;;;;;;;;;; SUBRUTINES ;;;;;;;;;;

;start manually
manuallyStart:
if (manualModeSupressDetection) {
  SetTimer, checkFullscreenWindow, off
}
Gosub startIt
return

;restart
startIt:
resetTimer()
startTimer()
return

stopIt:
resetTimer()
SetTimer, checkFullscreenWindow, on
SetTimer, CountDownTimer, off
return

quitIt:
ExitApp
return


; Add these hotkeys after the other hotkey definitions
~Ctrl::
Loop, %MonitorCount% {
  WinSet, ExStyle, -0x20, % "ahk_id " Guis[A_index]  ; Disable click-through when Ctrl is pressed
}
return

~Ctrl up::
Loop, %MonitorCount% {
  WinSet, ExStyle, +0x20, % "ahk_id " Guis[A_index]  ; Re-enable click-through when Ctrl is released
}
return

; Modify the GuiContextMenu section to use the shared menu
GuiContextMenu:
Menu, MainMenu, Show, %A_GuiX%, %A_GuiY%
Loop, %MonitorCount% {
  WinSet, ExStyle, +0x20, % "ahk_id " Guis[A_index]
}
return


PlayFinishSound:
  IfExist %pt_FinishSoundFile%
    SoundPlay %pt_FinishSoundFile%
return

PlayWarningSound:
  IfExist %pt_WarningSoundFile%
    SoundPlay %pt_WarningSoundFile%
Return


GuiClose:
ExitApp
return







;;;;;;;;;; FUNCTIONS ;;;;;;;;;;

resetTimer() {
  Loop, %MonitorCount% {
    hCountDown := Guis[A_index]
    hText := Texts[A_index]
    ; msgbox, % hText
    Gui, %hCountDown%:Default
    Gui, Font, c%textColor%
    Gui, Color, %backgroundColor%
    GuiControl, font, %hText%
    GuiControl,, %hText%, % FormatSeconds(pt_Duration)
  }
}


startTimer() {
  global startTime
  SetTimer CountDownTimer, Off
  startTime := A_TickCount
  Loop, %MonitorCount% {
    hCountDown := Guis[A_index]
    hText := Texts[A_index]
    Gui, %hCountDown%:Default
    GuiControl,, %hText%, % FormatSeconds(pt_Duration)
  }
  SetTimer CountDownTimer, 250
  SetTimer CountDownTimer, on
}


CountDownTimer(){
  global startTime, remaining
  elapsed := (A_TickCount - startTime) // 1000
  if (remaining != pt_Duration - elapsed) {
    remaining := pt_Duration - elapsed
    updateCountDownText()
  }
}

updateCountDownText(){
  global blink, remaining
  fg := textColor
  bg := backgroundColor
  if (remaining < 0){
    blink := !blink
    if (blink) {
      fg := timeoutColor
      bg := backgroundColor
    } else {
      fg := backgroundColor
      bg := timeoutColor
    }
  } else if (remaining <= pt_Ahead) {
    fg := AheadColor
    bg := backgroundColor
  }

  Loop, %MonitorCount% {
    hCountDown := Guis[A_index]
    hText := Texts[A_index]
    Gui, %hCountDown%:Default
    Gui, Font, c%fg%
    gui, color, %bg%
    GuiControl,, %hText%, % FormatSeconds(remaining)
    GuiControl, Font, %hText%
  }

  if (remaining = pt_Ahead && pt_PlayWarningSound){
    Gosub PlayWarningSound
  }
  if (remaining = 0 && pt_PlayFinishSound){
    Gosub PlayFinishSound
  }
}

refreshUI() {
  SysGet, MonitorCount, MonitorCount
  if (lastMonitor > MonitorCount || lastMonitor < 1) {
    lastMonitor := 1
  }

  Loop, %MonitorCount% {
    SysGet, Monitor, Monitor, %A_index%
    dpi_scale := GetDpiForMonitor(EnumMonitors()[A_index]) / 96

    bannerWidth_scaled := bannerWidth * dpi_scale
    bannerHeight_scaled := bannerHeight * dpi_scale
    fontsize_scaled := fontsize * dpi_scale

    MonitorWidth := MonitorRight - MonitorLeft
    xposition := MonitorLeft + (MonitorWidth - bannerWidth_scaled)

    hCountDown := Guis[A_index]
    hText := Texts[A_index]
    Gui, %hCountDown%:Default
    GuiControl, Move, %hText%, w%bannerWidth_scaled% h%bannerHeight_scaled%
    Gui, Font, %fontweight% s%fontsize_scaled% c%textColor% textcenter, %fontface%
    GuiControl, Font, %hText%
    if (!isPptTimerOn) {
      GuiControl,, %hText%, % FormatSeconds(pt_Duration)
    }
    Gui, Color, %backgroundColor%
    Winset, transparent, %opacity%, ahk_id %hCountDown%

    if (showOnAllMonitors) {
      Gui, Show, x%xposition% y%monitorTop% w%bannerWidth_scaled% h%bannerHeight_scaled%
      WinShow, % "ahk_id " Guis[A_index]
    } else {
      if (A_index != lastMonitor) {
        Winhide, % "ahk_id " Guis[A_index]
      } else {
        Gui, Show, x%xposition% y%monitorTop% w%bannerWidth_scaled% h%bannerHeight_scaled%
        WinShow, % "ahk_id " Guis[A_index]
      }
    }
  }
}

; Move Countdown to Next Monitor
moveToNextMonitor(){
  if (!showOnAllMonitors) {
    SysGet, MonitorCount, MonitorCount
    lastMonitor++
    if (lastMonitor > MonitorCount)
      lastMonitor := 1
    refreshUI()
    IniWrite, %lastMonitor%, %pt_IniFile%, status, lastMonitor
  }
}

toggleShowOnAllMonitors() {
  showOnAllMonitors := !showOnAllMonitors
  Menu, MonitorMenu, ToggleCheck, 1&
  if (showOnAllMonitors) {
    Menu, MonitorMenu, disable, 2&
  } else {
    Menu, MonitorMenu, enable, 2&
  }
  refreshUI()
  IniWrite, %showOnAllMonitors%, %pt_IniFile%, status, showOnAllMonitors
}


creatMenus(){
  Loop, 9 {
    idx := A_Index - 1
    loadProfile%idx% := Func("loadProfile").Bind(idx)
  }
  Menu, MainMenu, Add, % "开始计时`t" ReadableShortcut(startKey), manuallyStart
  Menu, MainMenu, Add, % "停止计时`t" ReadableShortcut(stopKey), stopIt
  Menu, MainMenu, Add
  if (profiles.Length() > 0) {
    Menu, ProfilesMenu, Add, % "默认配置`tCtrl+Win+F10",% loadProfile0, +Radio
    For index, profileid in profiles {
      InIRead, profilename, %pt_IniFile%, Profile_%profileid%, name, 预设 %profileid%
      Menu, ProfilesMenu, Add, % "(&" profileid ") " profilename "`tCtrl+Win+F" profileid, % loadProfile%profileid%, +Radio
      hotkey, ^#F%profileid%, % loadProfile%profileid%
    }
    if (lastProfile = 0) {
      Menu, ProfilesMenu, Check, 1&
    } else {
      targetIndex := HasVal(profiles, lastProfile) + 1
      Menu, ProfilesMenu, Check, %targetIndex%&
    }
    Menu, MainMenu, Add, 计时预设, :ProfilesMenu
    Menu, MainMenu, Add
  }
  if (MonitorCount > 1) {
    Menu, MonitorMenu, Add, % "在所有显示器显示", toggleShowOnAllMonitors
    Menu, MonitorMenu, Add, % "移至下个显示器`t" ReadableShortcut(moveKey), moveToNextMonitor
    if (showOnAllMonitors) {
      Menu, MonitorMenu, check, % "在所有显示器显示"
      Menu, MonitorMenu, disable, % "移至下个显示器`t" ReadableShortcut(moveKey)
    }
    Menu, MainMenu, Add, 多显示器, :MonitorMenu
    Menu, MainMenu, Add
  }

  Menu, MainMenu, Add, % "退出`t" ReadableShortcut(quitKey), quitIt


  Menu, Tray, NoStandard
  Menu, Tray, Add, % "开始计时`t" ReadableShortcut(startKey), manuallyStart
  Menu, Tray, Add, % "停止计时`t" ReadableShortcut(stopKey), stopIt
  Menu, Tray, Add
  if (profiles.Length() > 0) {
    Menu, Tray, Add, 计时预设, :ProfilesMenu
    Menu, Tray, Add
  }
  if (MonitorCount > 1) {
    Menu, Tray, Add, 多显示器, :MonitorMenu
    Menu, Tray, Add
  }
  Menu, Tray, Add, % "退出`t" ReadableShortcut(quitKey), quitIt

}

loadSettings(){
  InIRead, lastProfile, %pt_IniFile%, status, lastProfile, 0

  InIRead, startKey, %pt_IniFile%, shortcuts, startKey, F12
  InIRead, stopKey, %pt_IniFile%, shortcuts, stopKey, ^F12
  InIRead, quitKey, %pt_IniFile%, shortcuts, quitKey, #ESC
  InIRead, moveKey, %pt_IniFile%, shortcuts, moveKey, ^#M
  InIRead, allMonitorKey, %pt_IniFile%, shortcuts, allMonitorKey, ^#A

  InIRead, lastMonitor, %pt_IniFile%, status, lastMonitor, 1
  InIRead, manualModeSupressDetection, %pt_IniFile%, status, manualModeSupressDetection, 1
  InIRead, showOnAllMonitors, %pt_IniFile%, status, showOnAllMonitors, 0

  ; Hotkeys
  hotkey, %startKey%, manuallyStart
  hotkey, %stopKey%, stopIt
  hotkey, %quitKey%, quitIt
  hotkey, %moveKey%, moveToNextMonitor
  hotkey, %allMonitorKey%, toggleShowOnAllMonitors

  InIRead, sectionNams, %pt_IniFile%
  Loop, parse, sectionNams, `n, `r
  {
    found := RegExMatch(A_LoopField, "i)Profile_(?P<Idx>[1-9])$", Profile)
    if (found > 0) {
      profiles.push(ProfileIdx)
    }
  }

  if (profiles.Length() = 0) {
    lastProfile := 0
    IniWrite, 0, %pt_IniFile%, status, lastProfile
  }

  loadProfile(lastProfile)

}

loadProfile(idx) {
  local ProfileSectionName
  loadDefaultProfile()
  if (idx > 0) {
    ProfileSectionName := "Profile_" idx
    InIRead, fontface, %pt_IniFile%, %ProfileSectionName%, fontface, %fontface%
    InIRead, fontweight, %pt_IniFile%, %ProfileSectionName%, fontweight, %fontweight%
    InIRead, fontsize, %pt_IniFile%, %ProfileSectionName%, fontsize, %fontsize%
    InIRead, textColor, %pt_IniFile%, %ProfileSectionName%, textcolor, %textColor%

    InIRead, AheadColor, %pt_IniFile%, %ProfileSectionName%, aheadColor, %AheadColor%
    InIRead, timeoutColor, %pt_IniFile%, %ProfileSectionName%, timeoutColor, %timeoutColor%

    InIRead, opacity, %pt_IniFile%, %ProfileSectionName%, opacity, %opacity%
    InIRead, backgroundColor, %pt_IniFile%, %ProfileSectionName%, backgroundColor, %backgroundColor%
    InIRead, bannerWidth, %pt_IniFile%, %ProfileSectionName%, width, %bannerWidth%
    InIRead, bannerHeight, %pt_IniFile%, %ProfileSectionName%, height, %bannerHeight%

    InIRead, pt_Duration, %pt_IniFile%, %ProfileSectionName%, Duration, %pt_Duration%
    InIRead, pt_Ahead, %pt_IniFile%, %ProfileSectionName%, Ahead, %pt_Ahead%

    InIRead, pt_PlayWarningSound, %pt_IniFile%, %ProfileSectionName%, PlayWarningSound, %pt_PlayWarningSound%
    InIRead, pt_WarningSoundFile, %pt_IniFile%, %ProfileSectionName%, WarningSoundFile, %pt_WarningSoundFile%

    InIRead, pt_PlayFinishSound, %pt_IniFile%, %ProfileSectionName%, PlayFinishSound, %pt_PlayFinishSound%
    InIRead, pt_FinishSoundFile, %pt_IniFile%, %ProfileSectionName%, FinishSoundFile, %pt_FinishSoundFile%
  }
  refreshUI()
  if (idx != lastProfile) {
    if (A_ThisMenu != "") {
      currentMenuPos := HasVal(profiles, idx) + 1
      lastProfileMenuPos := HasVal(profiles, lastProfile) + 1
      Menu, ProfilesMenu, Check, %currentMenuPos%&
      Menu, ProfilesMenu, Uncheck, %lastProfileMenuPos%&
    }
    lastProfile := idx
    IniWrite, %idx%, %pt_IniFile%, status, lastProfile
  }
}

loadDefaultProfile(){
  InIRead, fontface, %pt_IniFile%, Main, fontface, "Microsoft Yahei"
  InIRead, fontweight, %pt_IniFile%, Main, fontweight, bold
  InIRead, fontsize, %pt_IniFile%, Main, fontsize, 24
  InIRead, textColor, %pt_IniFile%, Main, textcolor, 000000

  InIRead, AheadColor, %pt_IniFile%, Main, aheadColor, 9D1000
  InIRead, timeoutColor, %pt_IniFile%, Main, timeoutColor, FF0000

  InIRead, opacity, %pt_IniFile%, Main, opacity, 180
  InIRead, backgroundColor, %pt_IniFile%, Main, backgroundColor, FFFFAA
  InIRead, bannerWidth, %pt_IniFile%, Main, width, 200
  InIRead, bannerHeight, %pt_IniFile%, Main, height, 60

  InIRead, pt_Duration, %pt_IniFile%, Main, Duration, 300
  InIRead, pt_Ahead, %pt_IniFile%, Main, Ahead, 120

  InIRead, pt_PlayWarningSound, %pt_IniFile%, Main, PlayWarningSound, %True%
  InIRead, pt_WarningSoundFile, %pt_IniFile%, Main, WarningSoundFile, %A_ScriptDir%\beep.mp3

  InIRead, pt_PlayFinishSound, %pt_IniFile%, Main, PlayFinishSound, %True%
  InIRead, pt_FinishSoundFile, %pt_IniFile%, Main, FinishSoundFile, %A_ScriptDir%\applause.mp3

}

checkFullscreenWindow(){
  if (isAnyFullscreenWindow()) {
    if (!isPptTimerOn) {
      isPptTimerOn := true
      resetTimer()
      startTimer()
    }
  } else {
    if (isPptTimerOn) {
      isPptTimerOn := false
      resetTimer()
      SetTimer CountDownTimer, off
    }
  }
}


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

FormatSeconds(NumberOfSeconds)  ; Convert the specified number of seconds to hh:mm:ss format.
{
  time = 19990101  ; *Midnight* of an arbitrary date.

  if (NumberOfSeconds < 0){
    revert := "+"
    NumberOfSeconds := -NumberOfSeconds
  }

  time += % Mod(NumberOfSeconds, 3600), seconds
  FormatTime, mmss, %time%, mm:ss

  if (NumberOfSeconds >= 3600) {
    hour := NumberOfSeconds // 3600
    mmss := hour ":" mmss
  }

  return revert mmss
}

; Function to convert AHK shortcuts to a readable string
ReadableShortcut(shortcut) {
  replacements := { "^": "Ctrl+", "!": "Alt+", "+": "Shift+", "#": "Win+" }
  readable := ""
  Loop, Parse, shortcut
  {
    char := A_LoopField
    if (replacements.HasKey(char)){
      readable .= replacements[char]
    } else {
      readable .= char
    }
  }
  return readable
}

; Checks if a value exists in an array (similar to HasKey)
; FoundPos := HasVal(Haystack, Needle)
HasVal(haystack, needle) {
  for index, value in haystack
    if (value = needle)
      return index
  if !(IsObject(haystack))
    throw Exception("Bad haystack!", -1, haystack)
  return 0
}

EnumMonitors() {
   static EnumProc := RegisterCallback("MonitorEnumProc")
   Monitors := []
   return DllCall("User32\EnumDisplayMonitors", "Ptr", 0, "Ptr", 0, "Ptr", EnumProc, "Ptr", &Monitors, "Int") ? Monitors : false
}

MonitorEnumProc(hMonitor, hDC, pRECT, ObjectAddr) {
   Monitors := Object(ObjectAddr)
   Monitors.Push(hMonitor)
   return true
}
GetDpiForMonitor(hMonitor, Monitor_Dpi_Type := 0) {  ; MDT_EFFECTIVE_DPI = 0 (shellscalingapi.h)
   if !DllCall("Shcore\GetDpiForMonitor", "Ptr", hMonitor, "UInt", Monitor_Dpi_Type, "UInt*", dpiX, "UInt*", dpiY, "UInt")
      ; return {x:dpiX, y:dpiY}
      return dpiX
}
GetDpiForWindow(hwnd) {
   return DllCall("User32\GetDpiForWindow", "Ptr", hwnd, "UInt")
}
