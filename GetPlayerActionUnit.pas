{
  Copyright 2003-2005 Michalis Kamburelis.

  This file is part of "kambi_lines".

  "kambi_lines" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "kambi_lines" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "kambi_lines"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

unit GetPlayerActionUnit;

interface

uses LinesBoard, VectorMath;

type
  TPlayerAction = (paMove, paNewGame, paQuit);
  { ruch jest poprawny kiedy
      A nie jest polem pustym
      B jest polem pustym
      WayOnTheBoard odpowiedzialo true dla tej drogi. }
  TPlayerMove = record A, B: TVector2Integer end;

{ do loop with glw window waiting for player move. Zwraca TPlayerAction
  i jezeli zwrocil paMove to PlayerMove ustawia na odpowiedni Move a
  PlayerMoveWay na odpowiednia droge, taka jaka wygenerowalo WayOnTheBoard.
  (ruch w PlayerMove na pewno jest poprawny)
  Mozesz przekazac PlayerMoveWay = nil jesli nie interesuje cie droga. }
function GetPlayerAction(var PlayerMove: TPlayerMove;
  PlayerMoveWay: TDynVector2IntegerArray): TPlayerAction;

implementation

uses SysUtils, GL, GLU, GLExt, LinesWindow, GLWindow, KambiGLUtils, KambiUtils,
  Images, GLWinMessages, Classes, HighscoresUnit, GLWinModes,
  DrawingGame, LinesGame, GLWinInputs, LinesHelp, Areas,
  KambiStringUtils;

{ zmienne wewn. w tym module ----------------------------------------------- }

type
  TMoveState = (msNone, msSourceSelected, msTargetSelected);

var
  MoveState: TMoveState;
  Action: TPlayerAction;
  { if MoveState = msNone than Move is not initialized;
    if MoveState = msSourceSelected only X1, Y1 are initialized and
    if MoveState = msTargetSelected everything is initialized. }
  Move: TPlayerMove;
  { MoveWay is always created (non-nil) but it is initialized to some
    valid content only when MoveState = msTargetSelected. }
  MoveWay: TDynVector2IntegerArray;

  HighlightOneBF: boolean;
  HighlightOneBFPos: TVector2Integer;

  { HighlightWay = true mowi zeby DrawGL wyswietlilo droge z Move.A do
    HighlightWayPos. HighlightWay moze byc = true tylko
    gdy Action = paMove and MoveState = msSourceSelected.

    Naturalnie spodziewamy sie ze DrawGL uzyje wersji cached CWayOnTheBoard
    zeby obliczyc sobie way w szybki i wygodny sposob. Chociaz
    zasadnicza optymalizacja nie jest tu zawarta w CWayOnTheBoard,
    zasadnicza optymalizacja jest ze PostRedisplay nie jest wywolywane
    zbyt czesto przez MouseMove, a dokladniej - tylko gdy jakies zmienne
    Highlight* ulegna zmianie.
  }
  HighlightWay: boolean;
  HighlightWayPos: TVector2Integer;

{ gl window callbacks -------------------------------------------------------- }

procedure DrawGL(glwin: TGLWindow);
var HWay: TDynVector2IntegerArray;
begin
 if HighlightWay and CWayOnTheBoard(Move.A, HighlightWayPos) then
  HWay := CWayResultWay else
  HWay := nil;;
 DrawGame(HighlightOneBF, HighlightOneBFPos, HWay);

 if (Action = paMove) and (MoveState <> msNone) then
 begin
  glColorv(Vector3Byte(255, 255, 0));
  glLineWidth(3);
  DrawGLRectBorder(BoardField0X + Move.A[0] * BoardFieldWidth,
                   BoardField0Y + Move.A[1] * BoardFieldHeight,
		   BoardField0X + (Move.A[0]+1) * BoardFieldWidth,
                   BoardField0Y + (Move.A[1]+1) * BoardFieldHeight);
  glLineWidth(1);
 end;
end;

procedure AskQuit(glwin: TGLWindow);
begin
 if MessageYesNo(glwin, 'Are you sure you want to quit ?') then
  Action := paQuit;
end;

procedure KeyDown(glwin: TGLWindow; key: TKey; c: char);
begin
 case Key of
  K_F1: ShowHelp;
  else
   case c of
    'r':
      if MessageYesNo(glwin, 'End this game and start another one ?') then
       Action := paNewGame;
    CharEscape: AskQuit(glwin);
    'h':
      begin
       DrawGame;
       DrawHighscores;
       InputAnyKey(glw, GL_BACK, false, ScreenX0, ScreenY0);
      end;
    'n':ShowNextColors := not ShowNextColors;
    'i': BallsImageSet := ChangeIntCycle(BallsImageSet, 1, High(BallsImageSet));
    's': AllowSpecialBalls := not AllowSpecialBalls;
    else Exit;
   end;
 end;

 glwin.PostRedisplay;
end;

function GLWinMouseXToOurX(MouseX: Integer): Integer;
begin
 result := MouseX + ScreenX0;
end;

function GLWinMouseYToOurY(MouseY: Integer): Integer;
begin
 result := glw.Height-MouseY + ScreenY0;
end;

function MousePosToBoard(MouseX, MouseY: Integer; var BoardPos: TVector2Integer): boolean;
{ funkcja pomocnicza, oblicza nad jakim polem Board jest pozycje MouseX, MouseY
  podawana w konwencji MouseX, MouseY z glwindow. }
var TryPos: TVector2Integer;
begin
 MouseX := GLWinMouseXToOurX(MouseX);
 MouseY := GLWinMouseYToOurY(MouseY);

 if (MouseX < BoardField0X) or (MouseY < BoardField0Y) then Exit(false);

 TryPos[0]:=(MouseX-BoardField0X) div BoardFieldWidth;
 if TryPos[0] >= BoardWidth then Exit(false);

 TryPos[1]:=(MouseY-BoardField0Y) div BoardFieldHeight;
 if TryPos[1] >= BoardHeight then Exit(false);

 BoardPos := TryPos;
 result := true;
end;

procedure MouseMoveGL(glwin: TGLWindow; NewX, NewY: Integer);
var NewHighlightOneBF: boolean;
    NewHighlightOneBFPos, BoardPos: TVector2Integer;
    NewHighlightWay: boolean;
    NewHighlightWayPos: TVector2Integer;
begin
 NewHighlightOneBF := false;
 NewHighlightWay := false;

 if (Action = paMove) and (MoveState = msNone) and
   MousePosToBoard(NewX, NewY, BoardPos) then
 begin
  NewHighlightOneBFPos := BoardPos;
  NewHighlightOneBF := true;
 end else
 if (Action = paMove) and (MoveState = msSourceSelected) and
   MousePosToBoard(NewX, NewY, BoardPos) then
 begin
  NewHighlightWayPos := BoardPos;
  NewHighlightWay := true;
 end;

 { zrob PostRedisplay tylko jesli w New* cos sie zmienilo. W zasadzie
   moglibysmy tu sprawdzac NewHighlightOneBFX <> HighlightOneBFX tylko jesli
   NewHighlightOneBF = true, ale powinnismy uaktualniac HighlightOneBFX
   na NewHighlightOneBFX nawet jesli nie NewHighlightOneBF = true,
   wiec skomplikowaloby to nam kod. To i tak bez znaczenia o ile bedziemy
   zmieniac NewHighlightOneBFX/Y tylko przy ustawianiu NewHighlightOneBF na true.
 }
 if (NewHighlightOneBF <> HighlightOneBF) or
    (not CompareMem(@NewHighlightOneBFPos, @HighlightOneBFPos, SizeOf(TVector2Integer))) or
    (NewHighlightWay <> HighlightWay) or
    (not CompareMem(@NewHighlightWayPos, @HighlightWayPos, SizeOf(TVector2Integer)))
    then
 begin
  HighlightOneBF := NewHighlightOneBF;
  HighlightOneBFPos := NewHighlightOneBFPos;
  HighlightWay := NewHighlightWay;
  HighlightWayPos := NewHighlightWayPos;
  glwin.PostRedisplay;
 end;
end;

procedure MouseDownGL(glwin: TGLWindow; btn: TMouseButton);

  {$ifdef LINUX} procedure Beep; begin Write(#7) end; {$endif}

var BoardPos: TVector2Integer;
    AreaIndex: Integer;
begin
 if (Action = paMove) and (MoveState = msNone) and (btn = mbLeft) and
   MousePosToBoard(glwin.MouseX, glwin.MouseY, BoardPos) and
   (Board[BoardPos[0], BoardPos[1]] <> bfEmpty) then
 begin
  MoveState := msSourceSelected;
  Move.A := BoardPos;
  glwin.PostRedisplay;
 end else
 if (Action = paMove) and (MoveState = msSourceSelected) and (btn = mbLeft) and
   MousePosToBoard(glwin.MouseX, glwin.MouseY, BoardPos) then
 begin
  { jezeli kliknal na pustym to znaczy ze wybiera target.
    Wpp. znaczy ze wybiera ponownie source. }
  if Board[BoardPos[0], BoardPos[1]] = bfEmpty then
  begin
   if CWayOnTheBoard(Move.A, BoardPos) then
   begin
    MoveState := msTargetSelected;
    Move.B := BoardPos;
    MoveWay.Length := 0;
    MoveWay.AppendDynArray(CWayResultWay);
   end else
    { bardziej jasny komunikat, w rodzaju MessageOK(glw, 'No way found'),
      nie jest tu potrzebny bo podswietlamy droge z A do B wiec user i tak
      widzi ze nie ma drogi; po prostu przypadkiem kliknal sobie tutaj. }
    Beep;
  end else
   Move.A := BoardPos;
  glwin.PostRedisplay;
 end else
 if (btn = mbLeft) then
 begin
  { obslugujemy klikanie myszka na przyciskach ponizej }
  AreaIndex := DefaultAreas.FindArea(GLWinMouseXToOurX(glwin.MouseX),
    GLWinMouseYToOurY(glwin.MouseY));
  if AreaIndex >= 0 then
   case TPointerUInt(DefaultAreas.Items[AreaIndex].UserData) of
    0: glwin.EventKeyDown(K_F1, #0);
    1: glwin.EventKeyDown(K_None, 'i');
    2: glwin.EventKeyDown(K_None, 's');
    3: glwin.EventKeyDown(K_None, 'n');
    4: glwin.EventKeyDown(K_None, 'r');
   end;
 end;
end;

procedure CloseQueryGL(glwin: TGLWindow);
begin
 AskQuit(glwin);
end;

{ zasadnicze GetPlayerMove ------------------------------------------------- }

function GetPlayerAction(var PlayerMove: TPlayerMove;
  PlayerMoveWay: TDynVector2IntegerArray): TPlayerAction;
var SavedMode: TGLMode;
begin
 SavedMode := TGLMode.CreateReset(glw, 0, false, @DrawGL, nil, @CloseQueryGL, false);
 try
  glw.OnKeyDown := @KeyDown;
  glw.OnMouseMove := @MouseMoveGL;
  glw.OnMouseDown := @MouseDownGL;

  CWayClearCache;
  HighlightOneBF := false;
  HighlightWay := false;
  MoveState := msNone;
  Action := paMove;
  repeat
   Application.ProcessMessage(true);
  until (Action <> paMove) or (MoveState = msTargetSelected);

  result := Action;
  if result = paMove then
  begin
   PlayerMove := Move;
   if PlayerMoveWay <> nil then
   begin
    PlayerMoveWay.Length := 0;
    PlayerMoveWay.AppendDynArray(MoveWay);
   end;
  end;
 finally SavedMode.Free end;
end;

{ glw init/close --------------------------------------------------------- }

procedure InitGL(glwin: TGLWindow);
begin
 { dopiero w InitGL inicjuj Areas, na wypadek gdybym kiedys zrobil odczytywanie
   ImgButtonWidth/Height z pliku dopiero w DrawingGame.InitGL. }
 DefaultAreas.Add(Area( 20, StatusButtonsY, ImgButtonWidth, ImgButtonHeight, Pointer(0)));
 DefaultAreas.Add(Area(120, StatusButtonsY, ImgButtonWidth, ImgButtonHeight, Pointer(1)));
 DefaultAreas.Add(Area(256, StatusButtonsY, ImgButtonWidth, ImgButtonHeight, Pointer(2)));
 DefaultAreas.Add(Area(409, StatusButtonsY, ImgButtonWidth, ImgButtonHeight, Pointer(3)));
 DefaultAreas.Add(Area(509, StatusButtonsY, ImgButtonWidth, ImgButtonHeight, Pointer(4)));
end;

initialization
 glw.OnInitList.Add(@InitGL);
 MoveWay := TDynVector2IntegerArray.Create;
finalization
 FreeAndNil(MoveWay);
end.
