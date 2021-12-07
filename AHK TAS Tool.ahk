#NoEnv
#Warn All, MsgBox
#SingleInstance Force
SendMode Input
SetWorkingDir %A_ScriptDir%
;OPTIMIZATIONS START
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
ListLines Off
Process, Priority, , A
SetBatchLines, -1
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetWinDelay, -1
SetControlDelay, -1
;OPTIMIZATIONS END

NameText:="AHK TAS Tool"
,IsPlaying:=0
,IsFrameAdvance:=0
,DoneFrameNum:=0
,TASLength:=0
,TASFPS:=60
,StartTime:=0
,CanRun:=0

Gui, 1:New, hwndhGui AlwaysOnTop Resize MinSize
Gui, 1:Add, Text,, Input file content:
Gui, 1:Add, Button, Default yp xp+240 w80 gLoadFile, Load file (^O)
Gui, 1:Add, Edit, xm w320 r4 ReadOnly -Wrap vCtrl_InputFileContent
Gui, 1:Add, Button, w60 vPlayBackButton gPlayBack, Play (^R)
Gui, 1:Add, Button, yp xp+60 w70 vStopPlayBackButton gStopPlayBack, Reset (Esc)
Gui, 1:Add, Button, yp xp+70 w70 vFrameAdvanceButton gFrameAdvance, Frame (^F)
Gui, 1:Add, Text, xm , Frame:
Gui, 1:Add, Edit, yp xp+40 w80 r1 ReadOnly Right vCtrl_DoneFrameNum
Gui, 1:Add, Text, yp xp+100 w60 vCtrl_TASFPS, xx FPS
Gui, 1:Add, Text, xm w60, First frame:
Gui, 1:Add, Edit, yp xp+60 w40 r1 Right vCtrl_FirstFrame, 1
Gui, 1:Add, Text, yp xp+80 w60 vCtrl_ProcessedFrames, +xxF
Gui, 1:Add, Checkbox, checked yp-50 xp+80 w90 Right vCtrl_HotKeyEnabled, Use hot key
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

GetClientSize(hWnd, ByRef w := "", ByRef h := ""){
  VarSetCapacity(rect, 16)
  DllCall("GetClientRect", "ptr", hWnd, "ptr", &rect)
  w := NumGet(rect, 8, "int")
  h := NumGet(rect, 12, "int")
}

GuiClose:
ExitApp

$^o::
  if (Ctrl_HotKeyEnabled)
    gosub LoadFile
return

$^r::
  if (Ctrl_HotKeyEnabled)
    gosub PlayBack
return

$Esc::
  if (IsPlaying=1){
    gosub StopPlayBack
  }else if (Ctrl_HotKeyEnabled&&Ctrl_FirstFrame>1){
    UpdateText("Ctrl_FirstFrame",1)
  }else{
    Send {Esc}
  }
return

$^f::
  if (Ctrl_HotKeyEnabled)
    gosub FrameAdvance
return

LoadFile:
  FileSelectFile, InputFileName,
  FileRead, InputFileContent, %InputFileName%
  If (ErrorLevel=0){
    UpdateText("Ctrl_InputFileContent", InputFileContent)
    CanRun:=1
    ,InputFileLines:=StrSplit(InputFileContent,["`r`n","`n","`r"])
    ExpandLines()
    UpdateTASLength()
    UpdateTASConfiguration()
    PreprocessStartLineOfFrame()
  }Else{
    UpdateText("Ctrl_InputFileContent", "File read failed!")
    TASLength:=0
    ,CanRun:=0
  }
return

ExpandLines(){
  local line, command, arguments
  local ReadLineNum:=1
  local ReadArgumentNum
  local temp,temp2
  while (ReadLineNum<=InputFileLines.length()){
    line:=InputFileLines[ReadLineNum]
    command:=GetCommand(line)
    ,arguments:=GetArguments(line)
    if (command="frame"){
      ReadArgumentNum:=1
      ,temp:=""
      while (ReadArgumentNum<=arguments.length()){
        temp2:=ExpandArgument(arguments[ReadArgumentNum])
        if (temp!="")
          temp.=","
        temp.=temp2
        ,ReadArgumentNum+=1
      }
      InputFileLines[ReadLineNum]:="frame " temp
    }
    ReadLineNum+=1
  }
}

ExpandArgument(argument,variables:=0){
  local subarguments
  local temp,temp2,temp3
  if (!IsObject(variables))
    variables:={}
  argument:=ExpandPercentMaths(argument,variables)
  if (SubStr(argument,1,1)="*"){
    subarguments:=StrSplit(SubStr(argument,2),":")
    ,temp:=""
    ,temp2:=0
    while (subarguments.length()>5){
      subarguments[5].=":" subarguments[6]
      subarguments.RemoveAt(6,1)
    }
    while (temp2<subarguments[3]){
      variables[subarguments[1]]:=subarguments[2]+temp2*subarguments[4]
      temp3:=ExpandArgument(subarguments[5],variables)
      if (temp!="")
        temp.=","
      temp.=temp3
      ,temp2+=1
    }
    variables[subarguments[1]]:=subarguments[1]
    return temp
  }else{
    return argument
  }
}

ExpandPercentMaths(expression,ByRef variables){
  local skips:=0
  local firstmatch,secondmatch
  local result
  ;MsgBox % expression
  while (Instr(expression,"%",,,skips*2+2)){
    firstmatch:=Instr(expression,"%",,,skips*2+1)
    ,secondmatch:=Instr(expression,"%",,,skips*2+2)
    result:=PercentMath(SubStr(expression,firstmatch+1,secondmatch-firstmatch-1),variables)
    if (result)
      expression:=SubStr(expression,1,firstmatch-1) . result . SubStr(expression,secondmatch+1)
    else
      skips+=1
  }
  ;MsgBox % expression
  return expression
}

PercentMath(expression,ByRef variables){
  local substituted:=expression
  local k,v
  local tokens:=[]
  local ReadCharacterIndex:=1
  local temp
  local character
  local ReadTokenIndex:=1
  local token
  for k,v in variables{
    substituted:=StrReplace(substituted,k,v)
  }
  if (RegExMatch(substituted,"[^0-9\+\-\*\/]"))
    return ""
  while (ReadCharacterIndex<=StrLen(substituted)){
    character:=SubStr(substituted,ReadCharacterIndex,1)
    if (InStr("0123456789",character)){
      temp:=RegExMatch(substituted,"[\+\-\*\/]",,ReadCharacterIndex)
      if (temp){
        tokens.push(SubStr(substituted,ReadCharacterIndex,temp-ReadCharacterIndex))
        ReadCharacterIndex:=temp
      }else{
        tokens.push(SubStr(substituted,ReadCharacterIndex))
        ReadCharacterIndex:=StrLen(substituted)+1
      }
    }else{
      tokens.push(SubStr(substituted,ReadCharacterIndex,1))
      ReadCharacterIndex+=1
    }
  }
  while (ReadTokenIndex<=tokens.length()){
    token:=tokens[ReadTokenIndex]
    if (token="*"){
      if (ReadTokenIndex=1||ReadTokenIndex=tokens.length())
        return ""
      temp:=tokens[ReadTokenIndex-1]*tokens[ReadTokenIndex+1]
      tokens.RemoveAt(ReadTokenIndex,2)
      tokens[ReadTokenIndex-1]:=temp
    }else if (token="/"){
      if (ReadTokenIndex=1||ReadTokenIndex=tokens.length())
        return ""
      temp:=tokens[ReadTokenIndex-1]/tokens[ReadTokenIndex+1]
      tokens.RemoveAt(ReadTokenIndex,2)
      tokens[ReadTokenIndex-1]:=temp
    }else{
      ReadTokenIndex+=1
    }
  }
  ReadTokenIndex:=1
  while (ReadTokenIndex<=tokens.length()){
    token:=tokens[ReadTokenIndex]
    if (token="+"){
      ;MsgBox % "+" ReadTokenIndex
      if (ReadTokenIndex=1||ReadTokenIndex=tokens.length())
        return ""
      temp:=tokens[ReadTokenIndex-1]+tokens[ReadTokenIndex+1]
      tokens.RemoveAt(ReadTokenIndex,2)
      tokens[ReadTokenIndex-1]:=temp
    }else if (token="-"){
      if (ReadTokenIndex=1||ReadTokenIndex=tokens.length())
        return ""
      temp:=tokens[ReadTokenIndex-1]-tokens[ReadTokenIndex+1]
      tokens.RemoveAt(ReadTokenIndex,2)
      tokens[ReadTokenIndex-1]:=temp
    }else{
      ReadTokenIndex+=1
    }
  }
  if (tokens.length()=1)
    return tokens[1]
  else
    return ""
}

Update:
  Gui, 1:Submit, NoHide
  UpdateText("Ctrl_DoneFrameNum",DoneFrameNum "/" TASLength)
  if (CanRun=1){
    GuiControl, Enable, PlayBackButton
    GuiControl, Enable, FrameAdvanceButton
  }else{
    GuiControl, Disable, PlayBackButton
    GuiControl, Disable, FrameAdvanceButton
  }if (IsPlaying=1){
    GuiControl, Disable, PlayBackButton
    GuiControl, Disable, FrameAdvanceButton
  }
  If (IsPlaying=1){
    ProcessedFrames:=0
    while (IsPlaying=1&&DoneFrameNum<GetTimeElapsed()*TASFPS&&DoneFrameNum<=TASLength){
      DoneFrameNum+=1
      if (DoneFrameNum<=TASLength)
        ExecFrame(DoneFrameNum)
      ProcessedFrames+=1
      If (IsFrameAdvance=1)
        gosub StopPlayBack
    }
    if (DoneFrameNum>TASLength)
      gosub StopPlayBack
    UpdateText("Ctrl_DoneFrameNum",DoneFrameNum "/" TASLength)
    if (ProcessedFrames>=1){
      UpdateText("Ctrl_ProcessedFrames","+" ProcessedFrames "F")
      if (ProcessedFrames=1)
        GuiControl, +cBlack +Redraw, Ctrl_ProcessedFrames
      else
        GuiControl, +cRed +Redraw, Ctrl_ProcessedFrames
    }
  }
return

UpdateText(ControlID, NewText){
  static OldText := {}
  global hGui
  if (OldText[ControlID] != NewText){
    GuiControl, %hGui%:, % ControlID, % NewText
    OldText[ControlID] := NewText
  }
}

PlayBack:
  if (IsPlaying=1||CanRun=0)
    return
  DoneFrameNum:=Ctrl_FirstFrame-1
  if (CanRun=1){
    DllCall("QueryPerformanceFrequency", "Int64*",IsPlaying)
    DllCall("QueryPerformanceCounter", "Int64*",StartTime)
    StartTime-=IsPlaying*Ctrl_FirstFrame/TASFPS
    IsPlaying:=1
    IsFrameAdvance:=0
    if (Ctrl_HideWindow)
      WinHide, %NameText%
    GuiControl,, StopPlayBackButton, Stop (Esc)
  }
return

StopPlayBack:
  if (IsPlaying=0)
    return
  IsPlaying:=0
  WinShow, %NameText%
  UpdateText("Ctrl_FirstFrame",DoneFrameNum+1)
  GuiControl,, StopPlayBackButton, Reset (Esc)
return

FrameAdvance:
  if (IsPlaying=1||CanRun=0)
    return
  DoneFrameNum:=Ctrl_FirstFrame-1
  if (CanRun=1){
    DllCall("QueryPerformanceFrequency", "Int64*",IsPlaying)
    DllCall("QueryPerformanceCounter", "Int64*",StartTime)
    StartTime-=IsPlaying*Ctrl_FirstFrame/TASFPS
    IsPlaying:=1
    IsFrameAdvance:=1
  }
return

GetTimeElapsed(){ ;In seconds
  local freq:=0, currTime:=0
  DllCall("QueryPerformanceFrequency", "Int64*",freq)
  DllCall("QueryPerformanceCounter", "Int64*",currTime)
  return (currTime-StartTime)/freq
}

UpdateTASConfiguration(){
  local ReadLineNum,line,command,arguments
  ReadLineNum:=1
  TASFPS:=60
  MouseScale:=[1,1]
  MouseOffset:=[0,0]
  CoordMode, Mouse, Screen
  while (ReadLineNum<=InputFileLines.length()){
    line:=InputFileLines[ReadLineNum]
    command:=GetCommand(line)
    ,arguments:=GetArguments(line)
    if (command="fps"){
      TASFPS:=arguments[1]
      TASFPS+=0
    }else if (command="mouseScale"){
      MouseScale:=[arguments[1],arguments[2]]
      MouseScale[1]+=0
      MouseScale[2]+=0
    }else if (command="mouseOffset"){
      MouseOffset:=[arguments[1],arguments[2]]
      MouseOffset[1]+=0
      MouseOffset[2]+=0
    }else if (command="coordMode"){
      local mode
      StringLower, mode, % arguments[1]
      if (mode="screen"||mode="scr"||mode="s")
        CoordMode, Mouse, Screen
      else if (mode="relative"||mode="rel"||mode="r"||mode="window")
        CoordMode, Mouse, Relative
      else if (mode="client"||mode=="c")
        CoordMode, Mouse, Client
    }
    ReadLineNum+=1
  }
  UpdateText("Ctrl_TASFPS",TASFPS " FPS")
  return
}

UpdateTASLength(){
  local ReadLineNum,arguments,dashIndex,line
  ReadLineNum:=InputFileLines.length()
  while (ReadLineNum>0){
    line:=InputFileLines[ReadLineNum]
    if (GetCommand(line)="frame"){
      arguments:=GetArguments(line)
      dashIndex:=InStr(arguments[arguments.length()],"-")
      if (dashIndex)
        TASLength:=SubStr(arguments[arguments.length()],dashIndex+1)
      else
        TASLength:=arguments[arguments.length()]
      TASLength+=0
      break
    }
    ReadLineNum-=1
  }
  return
}

PreprocessStartLineOfFrame(){
  local line, command, arguments
  local ReadLineNum:=1
  local ReadArgumentNum
  local temp,temp2,dashIndex
  StartLineOfFrame:=[]
  temp:=1
  while (temp<=TASLength){
    StartLineOfFrame.push(0)
    temp+=1
  }
  while (ReadLineNum<=InputFileLines.length()){
    line:=InputFileLines[ReadLineNum]
    command:=GetCommand(line)
    ,arguments:=GetArguments(line)
    if (command="frame"){
      ReadArgumentNum:=1
      while (ReadArgumentNum<=arguments.length()){
        dashIndex:=InStr(arguments[ReadArgumentNum],"-")
        if (dashIndex=0){
          if (StartLineOfFrame[arguments[ReadArgumentNum]]=0)
            StartLineOfFrame[arguments[ReadArgumentNum]]:=ReadLineNum
        }else{
          temp:=SubStr(arguments[ReadArgumentNum],1,dashIndex-1)
          while (temp<=SubStr(arguments[ReadArgumentNum],dashIndex+1)){
            if (StartLineOfFrame[temp]=0)
              StartLineOfFrame[temp]:=ReadLineNum
            temp+=1
          }
        }
        ReadArgumentNum+=1
      }
    }
    ReadLineNum+=1
  }
}

GetStartLineOfFrame(frame){
  local ReadLineNum:=1
  local arguments,i,dashIndex
  return StartLineOfFrame[frame]
}

GetEndLineOfFrame(frame){
  local ReadLineNum:=GetStartLineOfFrame(frame)+1
  while (ReadLineNum<=InputFileLines.length()){
    if (GetCommand(InputFileLines[ReadLineNum])="frame")
      return ReadLineNum-1
    ReadLineNum+=1
  }
  return InputFileLines.length()
}

GetCommand(line){
  local space:=InStr(line," ")-1
  if (space=0)
    return line
  else
    return SubStr(line,1,InStr(line," ")-1)
}

GetArguments(line){
  local space:=InStr(line," ")-1
  if (space=0)
    return []
  else
    return StrSplit(SubStr(line,InStr(line," ")+1),",")
}

ExecFrame(frame){
  local ReadLineNum:=GetStartLineOfFrame(frame)
  if (ReadLineNum=0)
    return
  local EndLineNum:=GetEndLineOfFrame(frame)
  local line, command, arguments
  while (ReadLineNum<=EndLineNum){
    line:=InputFileLines[ReadLineNum]
    command:=GetCommand(line)
    ,arguments:=GetArguments(line)
    if (command="mousePos"){
      if (arguments.length()>=2)
        MouseMove, arguments[1]*MouseScale[1]+MouseOffset[1], arguments[2]*MouseScale[2]+MouseOffset[2], 0
    }else if (command="mousePosR"){
      if (arguments.length()>=2)
        MouseMove, arguments[1]*MouseScale[1]+MouseOffset[1], arguments[2]*MouseScale[2]+MouseOffset[2], 0, R
    }else if (command="fps"){
    }else if (command="frame"){
    }else if (command="send"){
      Send % SubStr(line,StrLen(command)+2)
    }else if (line!=""&&SubStr(line,1,1)!="#"){
      Send %line%
    }
    ReadLineNum+=1
  }
  return
}