#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetProductName ppttimer
;@Ahk2Exe-SetVersion 1.0

global Config := {
  IniFile: A_ScriptDir "\ppttimer.ini",
  ; Shortcuts
  startKey: "F12",
  stopKey: "^F12",
  resetKey: "^!F12",
  pauseKey: "^F11",
  quitKey: "#ESC",
  moveKey: "^#M",
  allMonitorKey: "^#A",
  ; Appearance
  opacity: 180,
  fontface: "Microsoft Yahei",
  fontweight: "bold",
  fontsize: 36,
  indicator_fontsize: 12,
  textColor: "000000",
  AheadColor: "9D1000",
  timeoutColor: "FF0000",
  backgroundColor: "FFFFAA",
  bannerWidth: 200,
  bannerHeight: 60,
  bannerPosition: "RT",
  bannerMargin: 0,
  ; Timer
  Duration: 300,
  Ahead: 120,
  stopResetsTimer: 0,
  sendOnTimeout: "0",
  manualModeSupressDetection: 1,
  ; Sound
  PlayFinishSound: true,
  FinishSoundFile: A_ScriptDir "\applause.mp3",
  PlayWarningSound: true,
  WarningSoundFile: A_ScriptDir "\beep.mp3",
  ; Exclusions
  exclusionExeList: "",
  exclusionClassList: "",
  exclusionTitleList: "",
  ; Debug
  DebugLevel: 0,
  DebugLogFile: ""
}

global State := {
  isPptTimerOn: false,
  startTime: 0,
  pauseTime: 0,
  remaining: 0,
  timeoutTriggered: false,
  blink: false,
  currentIndicator: "",
  currentFullscreenWinID: "",
  MonitorCount: 1,
  lastMonitor: 1,
  lastProfile: 0,
  showOnAllMonitors: 0,
  profiles: [],
  _enumMonitors: [],
  _enumCallback: 0
}

global UI := {
  Guis: [],
  Texts: [],
  Indicators: [],
  MainMenu: "",
  ProfilesMenu: "",
  MonitorMenu: "",
  profileCallbacks: Map()
}

Init()
return

~Ctrl::{
  for guiObj in UI.Guis {
    try WinSetExStyle("-0x20", "ahk_id " guiObj.Hwnd)
  }
}

~Ctrl up::{
  for guiObj in UI.Guis {
    try WinSetExStyle("+0x20", "ahk_id " guiObj.Hwnd)
  }
}

Init() {
  State.MonitorCount := MonitorGetCount()
  UI.Guis := []
  UI.Texts := []
  UI.Indicators := []

  Loop State.MonitorCount {
    DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

    guiObj := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
    durationText := guiObj.AddText("x0 y0 +0x200 Center", "")
    indicatorText := guiObj.AddText("x0 y0 +0x200 BackgroundTrans", "")

    guiObj.OnEvent("Close", (*) => ExitApp())
    guiObj.OnEvent("ContextMenu", ShowMainMenuFromGui)

    UI.Guis.Push(guiObj)
    UI.Texts.Push(durationText)
    UI.Indicators.Push(indicatorText)
  }

  ; Load config after GUI objects are created, because loadProfile() calls refreshUI().
  loadSettings()

  creatMenus()
  resetTimer()
  SetTimer(checkFullscreenWindow, 250)
}

ShowMainMenuFromGui(*) {
  MouseGetPos(&mx, &my)
  UI.MainMenu.Show(mx, my)

  for guiObj in UI.Guis {
    try WinSetExStyle("+0x20", "ahk_id " guiObj.Hwnd)
  }
}

manuallyStart(*) {
  if (Config.manualModeSupressDetection) {
    SetTimer(checkFullscreenWindow, 0)
  }
  startTimer()
}

quitIt(*) {
  ExitApp()
}

PlayFinishSound(*) {
  if FileExist(Config.FinishSoundFile) {
    SoundPlay(Config.FinishSoundFile)
  }
}

PlayWarningSound(*) {
  if FileExist(Config.WarningSoundFile) {
    SoundPlay(Config.WarningSoundFile)
  }
}

resetTimer(*) {
  State.isPptTimerOn := false
  State.pauseTime := 0
  State.timeoutTriggered := false
  State.currentIndicator := ""

  displayCount := Min(State.MonitorCount, UI.Guis.Length, UI.Texts.Length)
  Loop displayCount {
    guiObj := UI.Guis[A_Index]
    textCtrl := UI.Texts[A_Index]
    guiObj.BackColor := Config.backgroundColor
    textCtrl.SetFont("c" Config.textColor)
    textCtrl.Value := FormatSeconds(Config.Duration)
  }

  SetTimer(CountDownTimer, 0)
  SetTimer(checkFullscreenWindow, 250)
  updateIndicator()
}

startTimer(*) {
  State.isPptTimerOn := true
  State.pauseTime := 0
  State.startTime := A_TickCount
  State.timeoutTriggered := false
  State.currentIndicator := ""

  displayCount := Min(State.MonitorCount, UI.Guis.Length, UI.Texts.Length)
  Loop displayCount {
    guiObj := UI.Guis[A_Index]
    textCtrl := UI.Texts[A_Index]
    guiObj.BackColor := Config.backgroundColor
    textCtrl.SetFont("c" Config.textColor)
    textCtrl.Value := FormatSeconds(Config.Duration)
  }

  updateIndicator()
  SetTimer(CountDownTimer, 250)
}

pauseTimer(*) {
  if !State.isPptTimerOn {
    return
  }

  if (State.pauseTime != 0) {
    State.startTime += A_TickCount - State.pauseTime
    SetTimer(CountDownTimer, 250)
    State.pauseTime := 0
    State.currentIndicator := ""
  } else {
    State.pauseTime := A_TickCount
    SetTimer(CountDownTimer, 0)
    State.currentIndicator := ";"
  }

  updateIndicator()
}

stopTimer(*) {
  if (Config.stopResetsTimer) {
    resetTimer()
    return
  }

  State.currentIndicator := "<"
  State.isPptTimerOn := false
  State.pauseTime := 0
  SetTimer(CountDownTimer, 0)
  SetTimer(checkFullscreenWindow, 250)
  updateIndicator()
}

CountDownTimer() {
  elapsed := (A_TickCount - State.startTime) // 1000
  newRemaining := Config.Duration - elapsed
  if (State.remaining != newRemaining) {
    prevRemaining := State.remaining
    State.remaining := newRemaining
    updateCountDownText()

    if (prevRemaining > 0 && State.remaining <= 0 && !State.timeoutTriggered) {
      State.timeoutTriggered := true
      sendTimeoutKeys()
    }
  }
}

updateIndicator() {
  displayCount := Min(State.MonitorCount, UI.Guis.Length, UI.Indicators.Length)
  Loop displayCount {
    indicatorCtrl := UI.Indicators[A_Index]
    indicatorCtrl.Value := State.currentIndicator
  }
}

updateCountDownText() {
  fg := Config.textColor
  bg := Config.backgroundColor

  if (State.remaining < 0) {
    State.blink := !State.blink
    if (State.blink) {
      fg := Config.timeoutColor
      bg := Config.backgroundColor
    } else {
      fg := Config.backgroundColor
      bg := Config.timeoutColor
    }
  } else if (State.remaining <= Config.Ahead) {
    fg := Config.AheadColor
    bg := Config.backgroundColor
  }

  displayCount := Min(State.MonitorCount, UI.Guis.Length, UI.Texts.Length)
  Loop displayCount {
    guiObj := UI.Guis[A_Index]
    textCtrl := UI.Texts[A_Index]

    guiObj.BackColor := bg
    textCtrl.SetFont("c" fg)
    textCtrl.Value := FormatSeconds(State.remaining)
  }

  if (State.remaining = Config.Ahead && Config.PlayWarningSound) {
    PlayWarningSound()
  }
  if (State.remaining = 0 && Config.PlayFinishSound) {
    PlayFinishSound()
  }
}

refreshUI() {
  State.MonitorCount := MonitorGetCount()
  if (State.lastMonitor > State.MonitorCount || State.lastMonitor < 1) {
    State.lastMonitor := 1
  }

  monitorHandles := EnumMonitors()

  Loop State.MonitorCount {
    if (A_Index > UI.Guis.Length || A_Index > UI.Texts.Length || A_Index > UI.Indicators.Length) {
      continue
    }

    DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

    MonitorGet(A_Index, &MonitorLeft, &MonitorTop, &MonitorRight, &MonitorBottom)

    dpi_scale := 0
    if (A_Index <= monitorHandles.Length) {
      dpi_scale := GetDpiForMonitor(monitorHandles[A_Index]) / 96
    }
    if !dpi_scale {
      dpi_scale := A_ScreenDPI / 96
    }

    fontsize_scaled := Config.fontsize * dpi_scale
    indicator_fontsize_scaled := Config.indicator_fontsize * dpi_scale
    bannerWidth_scaled := Config.bannerWidth * dpi_scale
    bannerHeight_scaled := Config.bannerHeight * dpi_scale
    bannerMargin_scaled := Config.bannerMargin * dpi_scale
    indicator_y_scaled := 2.5 * dpi_scale
    indicator_width_scaled := 40

    monitorWidth := MonitorRight - MonitorLeft
    monitorHeight := MonitorBottom - MonitorTop

    switch Config.bannerPosition {
      case "LT", "TL":
        xposition := MonitorLeft + bannerMargin_scaled
        yposition := MonitorTop + bannerMargin_scaled
      case "RT", "TR":
        xposition := MonitorRight - bannerWidth_scaled - bannerMargin_scaled
        yposition := MonitorTop + bannerMargin_scaled
      case "MT", "TM":
        xposition := MonitorLeft + monitorWidth / 2 - bannerWidth_scaled / 2
        yposition := MonitorTop + bannerMargin_scaled
      case "LB", "BL":
        xposition := MonitorLeft + bannerMargin_scaled
        yposition := MonitorBottom - bannerHeight_scaled - bannerMargin_scaled
      case "MB", "BM":
        xposition := MonitorLeft + monitorWidth / 2 - bannerWidth_scaled / 2
        yposition := MonitorBottom - bannerHeight_scaled - bannerMargin_scaled
      case "RB", "BR":
        xposition := MonitorRight - bannerWidth_scaled - bannerMargin_scaled
        yposition := MonitorBottom - bannerHeight_scaled - bannerMargin_scaled
      default:
        xposition := MonitorRight - bannerWidth_scaled - bannerMargin_scaled
        yposition := MonitorTop + bannerMargin_scaled
    }

    guiObj := UI.Guis[A_Index]
    textCtrl := UI.Texts[A_Index]
    indicatorCtrl := UI.Indicators[A_Index]

    indicatorCtrl.Move(, indicator_y_scaled, indicator_width_scaled)
    indicatorCtrl.SetFont("s" Round(indicator_fontsize_scaled), "Webdings")

    textCtrl.Move(,, bannerWidth_scaled, bannerHeight_scaled)
    textCtrl.SetFont(Config.fontweight " s" Round(fontsize_scaled) " c" Config.textColor, Config.fontface)

    if !State.isPptTimerOn {
      textCtrl.Value := FormatSeconds(Config.Duration)
    }
    guiObj.BackColor := Config.backgroundColor

    if (State.showOnAllMonitors || A_Index = State.lastMonitor) {
      guiObj.Show("x" Round(xposition) " y" Round(yposition) " w" Round(bannerWidth_scaled) " h" Round(bannerHeight_scaled) " NA")
      WinSetTransparent(Config.opacity, "ahk_id " guiObj.Hwnd)
      WinSetExStyle("+0x20", "ahk_id " guiObj.Hwnd)
    } else {
      guiObj.Hide()
    }
  }
}

moveToNextMonitor(*) {
  if State.showOnAllMonitors {
    return
  }

  State.MonitorCount := MonitorGetCount()
  State.lastMonitor += 1
  if (State.lastMonitor > State.MonitorCount) {
    State.lastMonitor := 1
  }

  refreshUI()
  IniWrite(State.lastMonitor, Config.IniFile, "status", "lastMonitor")
}

toggleShowOnAllMonitors(*) {
  State.showOnAllMonitors := !State.showOnAllMonitors

  if (State.MonitorCount > 1) {
    if (State.showOnAllMonitors) {
      UI.MonitorMenu.Check("1&")
      UI.MonitorMenu.Disable("2&")
    } else {
      UI.MonitorMenu.Uncheck("1&")
      UI.MonitorMenu.Enable("2&")
    }
  }

  refreshUI()
  IniWrite(State.showOnAllMonitors ? 1 : 0, Config.IniFile, "status", "showOnAllMonitors")
}

creatMenus() {
  UI.MainMenu := Menu()
  UI.ProfilesMenu := Menu()
  UI.MonitorMenu := Menu()

  Loop 10 {
    idx := A_Index - 1
    UI.profileCallbacks[idx] := loadProfile.Bind(idx)
  }

  UI.MainMenu.Add("开始计时`t" ReadableShortcut(Config.startKey), manuallyStart)
  UI.MainMenu.Add("停止计时`t" ReadableShortcut(Config.stopKey), stopTimer)
  UI.MainMenu.Add("重置计时`t" ReadableShortcut(Config.resetKey), resetTimer)
  UI.MainMenu.Add("暂停/恢复计时`t" ReadableShortcut(Config.pauseKey), pauseTimer)
  UI.MainMenu.Add()

  if (State.profiles.Length > 0) {
    UI.ProfilesMenu.Add("默认配置`tCtrl+Win+F10", UI.profileCallbacks[0])
    Hotkey("^#F10", UI.profileCallbacks[0])

    for _, profileid in State.profiles {
      profilename := IniRead(Config.IniFile, "Profile_" profileid, "name", "预设 " profileid)
      UI.ProfilesMenu.Add("(&" profileid ") " profilename "`tCtrl+Win+F" profileid, UI.profileCallbacks[profileid])
      Hotkey("^#F" profileid, UI.profileCallbacks[profileid])
    }

    if (State.lastProfile = 0) {
      UI.ProfilesMenu.Check("1&")
    } else {
      targetIndex := HasVal(State.profiles, State.lastProfile) + 1
      if (targetIndex > 0) {
        UI.ProfilesMenu.Check(targetIndex "&")
      }
    }

    UI.MainMenu.Add("计时预设", UI.ProfilesMenu)
    UI.MainMenu.Add()
  }

  if (State.MonitorCount > 1) {
    UI.MonitorMenu.Add("在所有显示器显示`t" ReadableShortcut(Config.allMonitorKey), toggleShowOnAllMonitors)
    UI.MonitorMenu.Add("移至下个显示器`t" ReadableShortcut(Config.moveKey), moveToNextMonitor)

    if (State.showOnAllMonitors) {
      UI.MonitorMenu.Check("1&")
      UI.MonitorMenu.Disable("2&")
    }

    UI.MainMenu.Add("多显示器", UI.MonitorMenu)
    UI.MainMenu.Add()
  }

  UI.MainMenu.Add("退出`t" ReadableShortcut(Config.quitKey), quitIt)

  tray := A_TrayMenu
  tray.Delete()
  tray.Add("开始计时`t" ReadableShortcut(Config.startKey), manuallyStart)
  tray.Add("停止计时`t" ReadableShortcut(Config.stopKey), stopTimer)
  tray.Add("重置计时`t" ReadableShortcut(Config.resetKey), resetTimer)
  tray.Add("暂停/恢复计时`t" ReadableShortcut(Config.pauseKey), pauseTimer)
  tray.Add()

  if (State.profiles.Length > 0) {
    tray.Add("计时预设", UI.ProfilesMenu)
    tray.Add()
  }
  if (State.MonitorCount > 1) {
    tray.Add("多显示器", UI.MonitorMenu)
    tray.Add()
  }
  tray.Add("退出`t" ReadableShortcut(Config.quitKey), quitIt)
}

loadSettings() {
  debugLevel := IniRead(Config.IniFile, "Main", "debugLevel", 0)
  Config.DebugLevel := validNumberOrDefault(debugLevel, 0)
  if (Config.DebugLevel > 0) {
    Config.DebugLogFile := A_ScriptDir "\ppttimer_debug.log"
  }

  Config.startKey := IniRead(Config.IniFile, "shortcuts", "startKey", "F12")
  Config.stopKey := IniRead(Config.IniFile, "shortcuts", "stopKey", "^F12")
  Config.resetKey := IniRead(Config.IniFile, "shortcuts", "resetKey", "^!F12")
  Config.pauseKey := IniRead(Config.IniFile, "shortcuts", "pauseKey", "^F11")
  Config.quitKey := IniRead(Config.IniFile, "shortcuts", "quitKey", "#ESC")
  Config.moveKey := IniRead(Config.IniFile, "shortcuts", "moveKey", "^#M")
  Config.allMonitorKey := IniRead(Config.IniFile, "shortcuts", "allMonitorKey", "^#A")

  State.showOnAllMonitors := IniRead(Config.IniFile, "status", "showOnAllMonitors", 0) + 0
  State.lastMonitor := IniRead(Config.IniFile, "status", "lastMonitor", 1) + 0
  State.lastProfile := IniRead(Config.IniFile, "status", "lastProfile", 0) + 0

  Config.exclusionExeList := IniRead(Config.IniFile, "Main", "exclusionExeList", "")
  Config.exclusionClassList := IniRead(Config.IniFile, "Main", "exclusionClassList", "")
  Config.exclusionTitleList := IniRead(Config.IniFile, "Main", "exclusionTitleList", "")

  Hotkey(Config.startKey, manuallyStart)
  Hotkey(Config.stopKey, stopTimer)
  Hotkey(Config.resetKey, resetTimer)
  Hotkey(Config.pauseKey, pauseTimer)
  Hotkey(Config.quitKey, quitIt)
  Hotkey(Config.moveKey, moveToNextMonitor)
  Hotkey(Config.allMonitorKey, toggleShowOnAllMonitors)

  State.profiles := []
  sectionNames := IniRead(Config.IniFile)
  for section in StrSplit(sectionNames, "`n", "`r") {
    if RegExMatch(section, "i)Profile_(?<Idx>[1-9])$", &profileMatch) {
      State.profiles.Push(profileMatch.Idx + 0)
    }
  }

  if (State.profiles.Length = 0) {
    State.lastProfile := 0
    IniWrite(0, Config.IniFile, "status", "lastProfile")
  }

  loadProfile(State.lastProfile)
}

loadProfile(idx, *) {
  loadDefaultProfile()

  if (idx > 0) {
    profileSectionName := "Profile_" idx

    Config.fontface := IniRead(Config.IniFile, profileSectionName, "fontface", Config.fontface)
    Config.fontweight := IniRead(Config.IniFile, profileSectionName, "fontweight", Config.fontweight)
    Config.fontsize := IniRead(Config.IniFile, profileSectionName, "fontsize", Config.fontsize)
    Config.textColor := IniRead(Config.IniFile, profileSectionName, "textcolor", Config.textColor)

    Config.AheadColor := IniRead(Config.IniFile, profileSectionName, "aheadColor", Config.AheadColor)
    Config.timeoutColor := IniRead(Config.IniFile, profileSectionName, "timeoutColor", Config.timeoutColor)

    Config.opacity := IniRead(Config.IniFile, profileSectionName, "opacity", Config.opacity)
    Config.backgroundColor := IniRead(Config.IniFile, profileSectionName, "backgroundColor", Config.backgroundColor)
    Config.bannerWidth := IniRead(Config.IniFile, profileSectionName, "width", Config.bannerWidth)
    Config.bannerHeight := IniRead(Config.IniFile, profileSectionName, "height", Config.bannerHeight)
    Config.bannerPosition := IniRead(Config.IniFile, profileSectionName, "position", Config.bannerPosition)
    Config.bannerMargin := IniRead(Config.IniFile, profileSectionName, "margin", Config.bannerMargin)

    Config.Duration := IniRead(Config.IniFile, profileSectionName, "Duration", Config.Duration)
    Config.Ahead := IniRead(Config.IniFile, profileSectionName, "Ahead", Config.Ahead)

    Config.PlayWarningSound := IniRead(Config.IniFile, profileSectionName, "PlayWarningSound", Config.PlayWarningSound)
    Config.WarningSoundFile := IniRead(Config.IniFile, profileSectionName, "WarningSoundFile", Config.WarningSoundFile)

    Config.PlayFinishSound := IniRead(Config.IniFile, profileSectionName, "PlayFinishSound", Config.PlayFinishSound)
    Config.FinishSoundFile := IniRead(Config.IniFile, profileSectionName, "FinishSoundFile", Config.FinishSoundFile)

    Config.manualModeSupressDetection := IniRead(Config.IniFile, profileSectionName, "manualModeSupressDetection", Config.manualModeSupressDetection)
    Config.stopResetsTimer := IniRead(Config.IniFile, profileSectionName, "stopResetsTimer", Config.stopResetsTimer)
    Config.sendOnTimeout := IniRead(Config.IniFile, profileSectionName, "sendOnTimeout", Config.sendOnTimeout)
  }

  Config.fontsize := validNumberOrDefault(Config.fontsize, 24)
  Config.opacity := validNumberOrDefault(Config.opacity, 180)
  Config.bannerWidth := validNumberOrDefault(Config.bannerWidth, 200)
  Config.bannerHeight := validNumberOrDefault(Config.bannerHeight, 60)
  Config.bannerMargin := validNumberOrDefault(Config.bannerMargin, 0)
  Config.Duration := validNumberOrDefault(Config.Duration, 1200)
  Config.Ahead := validNumberOrDefault(Config.Ahead, 120)

  Config.fontsize := Config.fontsize * 96 / A_ScreenDPI
  Config.PlayWarningSound := Config.PlayWarningSound + 0
  Config.PlayFinishSound := Config.PlayFinishSound + 0

  refreshUI()
  if State.isPptTimerOn {
    updateCountDownText()
  }

  if (idx != State.lastProfile) {
    currentMenuPos := HasVal(State.profiles, idx) + 1
    lastProfileMenuPos := HasVal(State.profiles, State.lastProfile) + 1

    if (UI.ProfilesMenu && currentMenuPos > 0) {
      UI.ProfilesMenu.Check(currentMenuPos "&")
    }
    if (UI.ProfilesMenu && lastProfileMenuPos > 0) {
      UI.ProfilesMenu.Uncheck(lastProfileMenuPos "&")
    }

    State.lastProfile := idx
    IniWrite(idx, Config.IniFile, "status", "lastProfile")
  }
}

loadDefaultProfile() {
  debugLevel := IniRead(Config.IniFile, "Main", "debugLevel", 0)
  Config.DebugLevel := validNumberOrDefault(debugLevel, 0)

  if (Config.DebugLevel > 0) {
    Config.DebugLogFile := A_ScriptDir "\ppttimer_debug.log"
  }

  Config.fontface := IniRead(Config.IniFile, "Main", "fontface", "Microsoft Yahei")
  Config.fontweight := IniRead(Config.IniFile, "Main", "fontweight", "bold")
  Config.fontsize := IniRead(Config.IniFile, "Main", "fontsize", 36)
  Config.textColor := IniRead(Config.IniFile, "Main", "textcolor", "000000")

  Config.AheadColor := IniRead(Config.IniFile, "Main", "aheadColor", "9D1000")
  Config.timeoutColor := IniRead(Config.IniFile, "Main", "timeoutColor", "FF0000")

  Config.opacity := IniRead(Config.IniFile, "Main", "opacity", 180)
  Config.backgroundColor := IniRead(Config.IniFile, "Main", "backgroundColor", "FFFFAA")
  Config.bannerWidth := IniRead(Config.IniFile, "Main", "width", 200)
  Config.bannerHeight := IniRead(Config.IniFile, "Main", "height", 60)
  Config.bannerPosition := IniRead(Config.IniFile, "Main", "position", "RT")
  Config.bannerMargin := IniRead(Config.IniFile, "Main", "margin", 0)

  Config.Duration := IniRead(Config.IniFile, "Main", "Duration", 300)
  Config.Ahead := IniRead(Config.IniFile, "Main", "Ahead", 120)

  Config.PlayWarningSound := IniRead(Config.IniFile, "Main", "PlayWarningSound", 1)
  Config.WarningSoundFile := IniRead(Config.IniFile, "Main", "WarningSoundFile", A_ScriptDir "\beep.mp3")

  Config.PlayFinishSound := IniRead(Config.IniFile, "Main", "PlayFinishSound", 1)
  Config.FinishSoundFile := IniRead(Config.IniFile, "Main", "FinishSoundFile", A_ScriptDir "\applause.mp3")

  Config.manualModeSupressDetection := IniRead(Config.IniFile, "Main", "manualModeSupressDetection", 1)
  Config.stopResetsTimer := IniRead(Config.IniFile, "Main", "stopResetsTimer", 0)
  Config.sendOnTimeout := IniRead(Config.IniFile, "Main", "sendOnTimeout", 0)
}

sendTimeoutKeys() {
  if (Config.sendOnTimeout = 0 || Config.sendOnTimeout = "") {
    return
  }

  for keyToken in StrSplit(Config.sendOnTimeout, ",") {
    keyToken := Trim(keyToken, " `t")
    if (keyToken = "") {
      continue
    }
    Send(keyToken)
    Sleep(300)
  }
}

checkFullscreenWindow() {
  if isAnyFullscreenWindow() {
    if !State.isPptTimerOn {
      startTimer()
    }
  } else {
    if State.isPptTimerOn {
      stopTimer()
    }
  }
}

isExcludedWindow(winExe, winClass, winTitle) {
  if (Config.exclusionExeList != "") {
    for value in SplitCsvList(Config.exclusionExeList) {
      if (winExe = value) {
        return true
      }
    }
  }

  if (Config.exclusionClassList != "") {
    for value in SplitCsvList(Config.exclusionClassList) {
      if (winClass = value) {
        return true
      }
    }
  }

  if (Config.exclusionTitleList != "") {
    for value in SplitCsvList(Config.exclusionTitleList) {
      if (winTitle = value) {
        return true
      }
    }
  }

  return false
}

SplitCsvList(input) {
  result := []
  for token in StrSplit(input, ",") {
    token := Trim(token, " `t")
    if (token != "") {
      result.Push(token)
    }
  }
  return result
}

isAnyFullscreenWindow() {
  monitorCount := MonitorGetCount()
  winList := WinGetList()

  for winID in winList {
    winSelector := "ahk_id " winID

    winStyle := WinGetStyle(winSelector)
    WinGetPos(&winX, &winY, &winWidth, &winHeight, winSelector)

    winProcessPath := ""
    winProcessName := ""
    try winProcessPath := WinGetProcessPath(winSelector)
    try winProcessName := WinGetProcessName(winSelector)

    winState := WinGetMinMax(winSelector)
    if (winState = -1) {
      continue
    }

    winTitle := WinGetTitle(winSelector)
    winClass := WinGetClass(winSelector)

    if (winClass = "Progman" || winClass = "WorkerW" || winClass = "TscShellContainerClass") {
      continue
    }
    if (winTitle = "") {
      continue
    }
    if isExcludedWindow(winProcessName, winClass, winTitle) {
      continue
    }

    Loop monitorCount {
      monitorIndex := A_Index
      MonitorGet(monitorIndex, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)

      monitorWidth := monitorRight - monitorLeft
      monitorHeight := monitorBottom - monitorTop

      isFullscreen := ((winStyle & 0x20800000) = 0)
      isFullscreen := isFullscreen && (winX = monitorLeft && winY = monitorTop)
      isFullscreen := isFullscreen && (winWidth = monitorWidth && winHeight = monitorHeight)

      if isFullscreen {
        if (State.currentFullscreenWinID != winID) {
          State.currentFullscreenWinID := winID
          logMessage("New fullscreen window detected: Class=" winClass ", Title=" winTitle ", Executable=" winProcessPath, 2)
        }
        return true
      }
    }
  }

  State.currentFullscreenWinID := ""
  return false
}

FormatSeconds(numberOfSeconds) {
  prefix := ""
  if (numberOfSeconds < 0) {
    prefix := "+"
    numberOfSeconds := -numberOfSeconds
  }

  absSeconds := Floor(numberOfSeconds)
  hours := absSeconds // 3600
  mins := Mod(absSeconds, 3600) // 60
  secs := Mod(absSeconds, 60)

  mmss := Format("{:02}:{:02}", mins, secs)
  if (hours > 0) {
    mmss := hours ":" mmss
  }

  return prefix mmss
}

ReadableShortcut(shortcut) {
  replacements := Map("^", "Ctrl+", "!", "Alt+", "+", "Shift+", "#", "Win+")
  readable := ""

  for ch in StrSplit(shortcut) {
    if replacements.Has(ch) {
      readable .= replacements[ch]
    } else {
      readable .= ch
    }
  }
  return readable
}

HasVal(haystack, needle) {
  if !IsObject(haystack) {
    throw Error("Bad haystack!", -1, haystack)
  }

  for index, value in haystack {
    if (value = needle) {
      return index
    }
  }
  return 0
}

EnumMonitors() {
  State._enumMonitors := []
  if !State._enumCallback {
    State._enumCallback := CallbackCreate(MonitorEnumProc, "Fast")
  }

  ok := DllCall("User32\EnumDisplayMonitors", "ptr", 0, "ptr", 0, "ptr", State._enumCallback, "ptr", 0, "int")
  return ok ? State._enumMonitors.Clone() : []
}

MonitorEnumProc(hMonitor, hDC, pRECT, lParam) {
  State._enumMonitors.Push(hMonitor)
  return 1
}

GetDpiForMonitor(hMonitor, monitorDpiType := 0) {
  if !hMonitor {
    return 0
  }
  result := DllCall("Shcore\GetDpiForMonitor", "ptr", hMonitor, "uint", monitorDpiType, "uint*", &dpiX := 0, "uint*", &dpiY := 0, "uint")
  return (result = 0) ? dpiX : 0
}

GetDpiForWindow(hwnd) {
  return DllCall("User32\GetDpiForWindow", "ptr", hwnd, "uint")
}

GuiDefaultFont() {
  ; v2 is Unicode-only; LOGFONT size for Unicode build is 92 bytes.
  szLF := 92
  lf := Buffer(szLF, 0)

  if DllCall("GetObject", "ptr", DllCall("GetStockObject", "int", 17, "ptr"), "int", szLF, "ptr", lf.Ptr) {
    name := StrGet(lf.Ptr + 28, 32)
    return {
      Name: name,
      Size: Round(Abs(NumGet(lf, 0, "int")) * (72 / A_ScreenDPI), 1),
      Weight: NumGet(lf, 16, "int"),
      Quality: NumGet(lf, 26, "uchar")
    }
  }
  return false
}

validNumberOrDefault(valueToCheck, defaultValue) {
  if !IsNumber(valueToCheck) {
    return defaultValue
  }

  numericValue := valueToCheck + 0
  if (numericValue < 0) {
    return defaultValue
  }
  return numericValue
}

logMessage(message, level := 1) {
  if (Config.DebugLevel >= level) {
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    logLine := "[" timestamp "] " message
    FileAppend(logLine "`n", Config.DebugLogFile, "UTF-8")
  }
}
