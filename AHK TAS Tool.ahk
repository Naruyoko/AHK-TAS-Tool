#NoEnv
#Warn All, MsgBox
#SingleInstance Force
SendMode Input
SetWorkingDir %A_ScriptDir%

NameText:="ASK TAS Tool"
IsPlaying:=0
DoneFrameNum:=0
TASLength:=0
TASFPS:=60
StartTime:=0
CanRun:=0

Gui, 1:New, hwndhGui AlwaysOnTop Resize MinSize
Gui, 1:Add, Text,, Input file content:
Gui, 1:Add, Button, Default yp xp+240 w80 gLoadFile, Load file (^O)
Gui, 1:Add, Edit, xm w320 r4 ReadOnly -Wrap vCtrl_InputFileContent
Gui, 1:Add, Button, w60 vPlayBackButton gPlayBack, Play (^R)
Gui, 1:Add, Button, yp xp+60 w70 vStopPlayBackButton gStopPlayBack, Stop (+Esc)
Gui, 1:Add, Text, yp xp+70 w60, First frame:
Gui, 1:Add, Edit, yp xp+60 w30 r1 Right vCtrl_FirstFrame, 1
Gui, 1:Add, Text, xm , Frame:
Gui, 1:Add, Edit, yp xp+40 w80 r1 ReadOnly Right vCtrl_DoneFrameNum
Gui, 1:Add, Text, yp xp+90 w80 vCtrl_TASFPS, FPS be here
Gui, 1:Add, Checkbox, checked yp-20 xp+90 w90 Right vCtrl_HotKeyEnabled, Use hot key
Gui, 1:Add, Checkbox, checked w90 Right vCtrl_HideWindow, Hide window
Gui, 1:Show, NoActivate, %NameText%
GetClientSize(hGui, temp)
horzMargin := temp*96//A_ScreenDPI - 320
SetTimer, Update, 16
return

GuiSize:
Gui %hGui%:Default
if !horzMargin
  return
SetTimer, Update, % A_EventInfo=1 ? "Off" : "On" ; Suspend on minimize
ctrlW := A_GuiWidth - horzMargin
list = Title,MousePos,Ctrl,Pos,SBText,VisText,AllText,Freeze
Loop, Parse, list, `,
  GuiControl, Move, Ctrl_%A_LoopField%, w%ctrlW%
return

GetClientSize(hWnd, ByRef w := "", ByRef h := "")
{
  VarSetCapacity(rect, 16)
  DllCall("GetClientRect", "ptr", hWnd, "ptr", &rect)
  w := NumGet(rect, 8, "int")
  h := NumGet(rect, 12, "int")
}

GuiClose:
ExitApp

^o::
if (Ctrl_HotKeyEnabled)
  gosub LoadFile
return

^r::
if (Ctrl_HotKeyEnabled)
  gosub PlayBack
return

+Esc::
gosub StopPlayBack
return

LoadFile:
FileSelectFile, InputFileName,
FileRead, InputFileContent, %InputFileName%
If (ErrorLevel=0)
{
  UpdateText("Ctrl_InputFileContent", InputFileContent)
  CanRun:=1
  InputFileLines:=StrSplit(InputFileContent,["`r`n","`n","`r"])
  UpdateTASLength()
  if (GetCommand(InputFileLines[1])="fps")
  {
    TASFPS:=GetArguments(InputFileLines[1])[1]
    TASFPS+=0
  }
  else
  {
    TASFPS:=60
  }
  UpdateText("Ctrl_TASFPS",TASFPS " FPS")
}
Else
{
  UpdateText("Ctrl_InputFileContent", "File read failed!")
  TASLength:=0
  CanRun:=0
}
return

Update:
Gui, 1:Submit, NoHide
CoordMode, Mouse, Screen
UpdateText("Ctrl_DoneFrameNum",DoneFrameNum "/" TASLength)
if (CanRun=1)
{
  GuiControl, Enable, PlayBackButton
}
else
{
  GuiControl, Disable, PlayBackButton
}
if (IsPlaying=1)
{
  GuiControl, Enable, StopPlayBackButton
}
else
{
  GuiControl, Disable, StopPlayBackButton
}
If (IsPlaying=1)
{
  while (DoneFrameNum<GetTimeElapsed()*TASFPS&&DoneFrameNum<=TASLength)
  {
    DoneFrameNum+=1
    if (DoneFrameNum<=TASLength)
      ExecFrame(DoneFrameNum)
  }
  if (DoneFrameNum>TASLength)
    gosub StopPlayBack
  UpdateText("Ctrl_DoneFrameNum",DoneFrameNum "/" TASLength)
}
return

UpdateText(ControlID, NewText)
{
  static OldText := {}
  global hGui
  if (OldText[ControlID] != NewText)
  {
    GuiControl, %hGui%:, % ControlID, % NewText
    OldText[ControlID] := NewText
  }
}

PlayBack:
DoneFrameNum:=Ctrl_FirstFrame-1
if (CanRun=1)
{
  DllCall("QueryPerformanceFrequency", "Int64*",IsPlaying)
  DllCall("QueryPerformanceCounter", "Int64*",StartTime)
  StartTime-=IsPlaying*Ctrl_FirstFrame/TASFPS
  IsPlaying:=1
  if (Ctrl_HideWindow)
    WinHide, %NameText%
}
return

StopPlayBack:
IsPlaying:=0
WinShow, %NameText%
return

GetTimeElapsed() ;In seconds
{
  local freq:=0, currTime:=0
  DllCall("QueryPerformanceFrequency", "Int64*",freq)
  DllCall("QueryPerformanceCounter", "Int64*",currTime)
  return (currTime-StartTime)/freq
}

UpdateTASLength()
{
  local ReadLineNum
  ReadLineNum:=InputFileLines.length()
  while (ReadLineNum>0)
  {
    if (GetCommand(InputFileLines[ReadLineNum])="frame")
    {
      TASLength:=GetArguments(InputFileLines[ReadLineNum])[1]
      TASLength+=0
      break
    }
    ReadLineNum-=1
  }
  return
}

GetStartLineOfFrame(frame)
{
  local ReadLineNum:=1
  local arguments,i,dashIndex
  while (ReadLineNum<=InputFileLines.length())
  {
    if (GetCommand(InputFileLines[ReadLineNum])="frame")
    {
      arguments:=GetArguments(InputFileLines[ReadLineNum])
      i:=1
      while (i<=arguments.length()){
        dashIndex:=InStr(arguments[i],"-")
        ;MsgBox % ReadLineNum "`n" InputFileLines[ReadLineNum] "`n" i "`n" arguments[i] "`n" dashIndex
        if ((dashIndex!=0&&SubStr(arguments[i],0,dashIndex)<=frame&&frame<=SubStr(arguments[i],dashIndex+1))||(dashIndex=0&&arguments[i]=frame))
          return ReadLineNum
        i+=1
      }
    }
    ReadLineNum+=1
  }
  return 0
}

GetEndLineOfFrame(frame)
{
  local ReadLineNum:=GetStartLineOfFrame(frame)+1
  while (ReadLineNum<=InputFileLines.length())
  {
    if (GetCommand(InputFileLines[ReadLineNum])="frame")
      return ReadLineNum-1
    ReadLineNum+=1
  }
  return InputFileLines.length()
}

GetCommand(line)
{
  local space:=InStr(line," ")-1
  if (space=0)
    return line
  else
    return SubStr(line,1,InStr(line," ")-1)
}

GetArguments(line)
{
  local space:=InStr(line," ")-1
  if (space=0)
    return []
  else
    return StrSplit(SubStr(line,InStr(line," ")+1),",")
}

ExecFrame(frame)
{
  local ReadLineNum:=GetStartLineOfFrame(frame)
  if (ReadLineNum=0)
    return
  local EndLineNum:=GetEndLineOfFrame(frame)
  local line, command, arguments
  while (ReadLineNum<=EndLineNum)
  {
    line:=InputFileLines[ReadLineNum]
    command:=GetCommand(line)
    arguments:=GetArguments(line)
    if (command="mousePos")
    {
      if (arguments.length()>=2)
        MouseMove, arguments[1]+0, arguments[2]+0
    }
    else if (command="fps")
    {
    }
    else if (command="frame")
    {
    }
    else if (command="send")
    {
      Send % SubStr(line,StrLen(command)+2)
    }
    else if (line!=""&&SubStr(line,1,1)!="#")
    {
      Send %line%
    }
    ReadLineNum+=1
  }
  return
}