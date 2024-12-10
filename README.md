# PPT 计时器
![ppttimer](ppttimer.png)

[下载](https://github.com/old9/ppttimer/releases)

一个 Windows 下简易的 PowerPoint 计时器，基于 [Autohotkey](http://autohotkey.com)。主要功能：
* PPT 开始播放时自动开始倒计时，结束放映时自动停止。
* 悬浮于最上层，鼠标可穿透，不影响其他操作。
* 字体和透明等可通过参数调节。
* 可手动开始停止计时器。

代码基于 [Yet Another CountDown Script](http://www.autohotkey.com/board/topic/19679-yet-another-countdown-script/) 修改，并参考了 [Countdown timer app](http://www.autohotkey.com/board/topic/57463-countdown-timer-app/)。

屏幕截图：

![Screenshot](screenshot.png)

## 安装使用方法

无需安装，[下载](https://github.com/old9/ppttimer/releases)并解压，运行 ppttimer.exe 即可开始使用。
程序启动后会自动侦测 PPT 的放映窗口，一旦 PPT 开始放映，则会自动启动计时器。
如果不是 PPT 放映，如 PDF 等其他演示方式，也可以通过快捷键手动启动。
默认的快捷键设置为，开始放映 `F12`，停止放映 `Ctrl`+`F12`，移动到下一个显示器 `Ctrl`+`Windows`+`M` 退出程序 `Windows`+`ESC`。

## ini 参数配置说明

```
[Main]
;倒计时时间，单位秒，默认为 1200 秒即 20 分钟。
Duration=1200

;提前提醒时间，单位秒。默认为 120 秒即 2 分钟。
Ahead=120
;提前提醒时是否播放声音及声音路径
PlayWarningSound=1
WarningSoundFile=.\beep.mp3

;时间到时是否播放声音及声音路径
PlayFinishSound=1
FinishSoundFile=.\applause.mp3

;窗口样式
;透明度
opacity=180
;窗口背景色
backgroundColor=FFFFAA
;窗口大小，位置固定在右上角
width=300
height=70

;字体样式
fontface=微软雅黑
fontweight=bold
fontsize=40
textcolor=000000

;提前提醒时的字体颜色
AheadColor=9D1000

;超时后的字体颜色
timeoutColor=FF0000

[shortcuts]
;快捷键设置，^ Ctrl，# Windows，+ Shift，! Alt。
;开始手动计时
startKey=F12
;停止计时器
stopKey=^F12
;移动到下一个显示器
moveKey=^#M
;退出主程序
quitKey=#ESC
```

## 编译方法
* 至 [Autohotkey 主页](https://autohotkey.com) 下载 Autohotkey 并安装。
* 使用安装后自带的编译打包工具 `Compiler\Ahk2Exe.exe` 编译 ahk 文件。

## TODO

* 更多可控制的参数
* 除 PPT 之外的其他窗口的自动侦测

## licence

Licensed under the MIT.