{
  Copyright 2003-2012 Michalis Kamburelis.

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

  ----------------------------------------------------------------------------
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
  PlayerMoveWay: TVector2IntegerList): TPlayerAction;

implementation

uses SysUtils, GL, GLU, GLExt, LinesWindow, CastleWindow, CastleGLUtils, CastleUtils,
  Images, CastleMessages, Classes, HighscoresUnit, WindowModes, UIControls,
  DrawingGame, LinesGame, CastleInputs, LinesHelp, Rectangles,
  CastleStringUtils, GLImages;

var
  ButtonsRects: TRectangleList;

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
  MoveWay: TVector2IntegerList;

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

procedure DrawGL(Window: TCastleWindowBase);
var HWay: TVector2IntegerList;
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

procedure AskQuit(Window: TCastleWindowBase);
begin
 if MessageYesNo(Window, 'Are you sure you want to quit ?') then
  Action := paQuit;
end;

procedure KeyDown(Window: TCastleWindowBase; key: TKey; c: char);
var
  DL: TGLuint;
begin
 case Key of
  K_F1: ShowHelp;
  else
   case c of
    'r':
      if MessageYesNo(Window, 'End this game and start another one ?') then
       Action := paNewGame;
    CharEscape: AskQuit(Window);
    'h':
      begin
       DrawGame;
       DrawHighscores;
       { directly get screenshot now, without redrawing with Window.OnDraw }
       DL := SaveScreen_ToDisplayList_NoFlush(0, 0, Window.Width, Window.Height,
         GL_BACK);
       try
         InputAnyKey(Window, DL, ScreenX0, ScreenY0, Window.Width, Window.Height);
       finally glFreeDisplayList(DL) end;
      end;
    'n':ShowNextColors := not ShowNextColors;
    'i': BallsImageSet := ChangeIntCycle(BallsImageSet, 1, High(BallsImageSet));
    's': AllowSpecialBalls := not AllowSpecialBalls;
    else Exit;
   end;
 end;

 Window.PostRedisplay;
end;

function GLWinMouseXToOurX(MouseX: Integer): Integer;
begin
 result := MouseX + ScreenX0;
end;

function GLWinMouseYToOurY(MouseY: Integer): Integer;
begin
 result := Window.Height-MouseY + ScreenY0;
end;

function MousePosToBoard(MouseX, MouseY: Integer; var BoardPos: TVector2Integer): boolean;
{ funkcja pomocnicza, oblicza nad jakim polem Board jest pozycje MouseX, MouseY
  podawana w konwencji MouseX, MouseY z Window. }
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

procedure MouseMoveGL(Window: TCastleWindowBase; NewX, NewY: Integer);
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
  Window.PostRedisplay;
 end;
end;

procedure MouseDownGL(Window: TCastleWindowBase; btn: TMouseButton);

  {$ifdef LINUX} procedure Beep; begin Write(#7) end; {$endif}

var BoardPos: TVector2Integer;
    RectangleIndex: Integer;
begin
 if (Action = paMove) and (MoveState = msNone) and (btn = mbLeft) and
   MousePosToBoard(Window.MouseX, Window.MouseY, BoardPos) and
   (Board[BoardPos[0], BoardPos[1]] <> bfEmpty) then
 begin
  MoveState := msSourceSelected;
  Move.A := BoardPos;
  Window.PostRedisplay;
 end else
 if (Action = paMove) and (MoveState = msSourceSelected) and (btn = mbLeft) and
   MousePosToBoard(Window.MouseX, Window.MouseY, BoardPos) then
 begin
  { jezeli kliknal na pustym to znaczy ze wybiera target.
    Wpp. znaczy ze wybiera ponownie source. }
  if Board[BoardPos[0], BoardPos[1]] = bfEmpty then
  begin
   if CWayOnTheBoard(Move.A, BoardPos) then
   begin
    MoveState := msTargetSelected;
    Move.B := BoardPos;
    MoveWay.Count := 0;
    MoveWay.AddList(CWayResultWay);
   end else
    { bardziej jasny komunikat, w rodzaju MessageOK(Window, 'No way found'),
      nie jest tu potrzebny bo podswietlamy droge z A do B wiec user i tak
      widzi ze nie ma drogi; po prostu przypadkiem kliknal sobie tutaj. }
    Beep;
  end else
   Move.A := BoardPos;
  Window.PostRedisplay;
 end else
 if (btn = mbLeft) then
 begin
  { obslugujemy klikanie myszka na przyciskach ponizej }
  RectangleIndex := ButtonsRects.FindRectangle(GLWinMouseXToOurX(Window.MouseX),
    GLWinMouseYToOurY(Window.MouseY));
  case RectangleIndex of
    0: Window.EventKeyDown(K_F1, #0);
    1: Window.EventKeyDown(K_None, 'i');
    2: Window.EventKeyDown(K_None, 's');
    3: Window.EventKeyDown(K_None, 'n');
    4: Window.EventKeyDown(K_None, 'r');
  end;
 end;
end;

procedure CloseQueryGL(Window: TCastleWindowBase);
begin
 AskQuit(Window);
end;

{ zasadnicze GetPlayerMove ------------------------------------------------- }

function GetPlayerAction(var PlayerMove: TPlayerMove;
  PlayerMoveWay: TVector2IntegerList): TPlayerAction;
var SavedMode: TGLMode;
begin
 SavedMode := TGLMode.CreateReset(Window, 0, false, @DrawGL, nil, @CloseQueryGL);
 try
  Window.OnKeyDown := @KeyDown;
  Window.OnMouseMove := @MouseMoveGL;
  Window.OnMouseDown := @MouseDownGL;

  CWayClearCache;
  HighlightOneBF := false;
  HighlightWay := false;
  MoveState := msNone;
  Action := paMove;
  repeat
   Application.ProcessMessage(true, true);
  until (Action <> paMove) or (MoveState = msTargetSelected);

  result := Action;
  if result = paMove then
  begin
   PlayerMove := Move;
   if PlayerMoveWay <> nil then
   begin
    PlayerMoveWay.Count := 0;
    PlayerMoveWay.AddList(MoveWay);
   end;
  end;
 finally SavedMode.Free end;
end;

{ glw open/close --------------------------------------------------------- }

procedure WindowOpen(const Container: IUIContainer);
begin
 { dopiero w OpenGL inicjuj Rectangles, na wypadek gdybym kiedys zrobil odczytywanie
   ImgButtonWidth/Height z pliku dopiero w DrawingGame.WindowOpen. }
 ButtonsRects.Add(Rectangle( 20, StatusButtonsY, ImgButtonWidth, ImgButtonHeight));
 ButtonsRects.Add(Rectangle(120, StatusButtonsY, ImgButtonWidth, ImgButtonHeight));
 ButtonsRects.Add(Rectangle(256, StatusButtonsY, ImgButtonWidth, ImgButtonHeight));
 ButtonsRects.Add(Rectangle(409, StatusButtonsY, ImgButtonWidth, ImgButtonHeight));
 ButtonsRects.Add(Rectangle(509, StatusButtonsY, ImgButtonWidth, ImgButtonHeight));
end;

initialization
 OnGLContextOpen.Add(@WindowOpen);
 MoveWay := TVector2IntegerList.Create;
 ButtonsRects := TRectangleList.Create;
finalization
 FreeAndNil(MoveWay);
 FreeAndNil(ButtonsRects);
end.
