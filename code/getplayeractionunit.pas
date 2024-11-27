{
  Copyright 2003-2022 Michalis Kamburelis.

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

{ }
unit GetPlayerActionUnit;

interface

uses LinesBoard, CastleVectors;

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

uses SysUtils, LinesWindow, CastleWindow, CastleGLUtils, CastleUtils,
  CastleImages, CastleMessages, Classes, HighscoresUnit, CastleWindowModes, CastleUIControls,
  DrawingGame, LinesGame, CastleInputAny, LinesHelp, CastleColors,
  CastleStringUtils, CastleGLImages, CastleKeysMouse, CastleRectangles,
  CastleControls, CastleApplicationProperties, CastleInternalControlsImages;

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

  { HighlightWay = true mowi zeby Render wyswietlilo droge z Move.A do
    HighlightWayPos. HighlightWay moze byc = true tylko
    gdy Action = paMove and MoveState = msSourceSelected.

    Naturalnie spodziewamy sie ze Render uzyje wersji cached CWayOnTheBoard
    zeby obliczyc sobie way w szybki i wygodny sposob. Chociaz
    zasadnicza optymalizacja nie jest tu zawarta w CWayOnTheBoard,
    zasadnicza optymalizacja jest ze Invalidate nie jest wywolywane
    zbyt czesto przez Motion, a dokladniej - tylko gdy jakies zmienne
    Highlight* ulegna zmianie.
  }
  HighlightWay: boolean;
  HighlightWayPos: TVector2Integer;

{ view ----------------------------------------------------------------------- }

type
  { View to contain whole UI and to handle events, like key press. }
  TMyView = class(TCastleView)
    procedure Render; override;
    function Motion(const Event: TInputMotion): Boolean; override;
    function Press(const Event: TInputPressRelease): Boolean; override;
  end;

procedure TMyView.Render;
var HWay: TVector2IntegerList;
begin
  inherited;

 if HighlightWay and CWayOnTheBoard(Move.A, HighlightWayPos) then
  HWay := CWayResultWay else
  HWay := nil;;
 DrawGame(HighlightOneBF, HighlightOneBFPos, HWay);

 if (Action = paMove) and (MoveState <> msNone) then
 begin
   Theme.Draw(Rectangle(
     BoardField0X + Move.A.X * BoardFieldWidth,
     BoardField0Y + Move.A.Y * BoardFieldHeight,
     BoardFieldWidth,
     BoardFieldHeight), tiActiveFrame);
 end;
end;

procedure AskQuit(Window: TCastleWindow);
begin
 if MessageYesNo(Window, 'Are you sure you want to quit ?') then
  Action := paQuit;
end;

function MousePosToBoard(const Position: TVector2; var BoardPos: TVector2Integer): boolean;
var
  TryPos: TVector2Integer;
  MouseX, MouseY: Integer;
begin
  MouseX := Round(Position.X);
  MouseY := Round(Position.Y);

  if (MouseX < BoardField0X) or (MouseY < BoardField0Y) then Exit(false);

  TryPos.X:=(MouseX-BoardField0X) div BoardFieldWidth;
  if TryPos.X >= BoardWidth then Exit(false);

  TryPos.Y:=(MouseY-BoardField0Y) div BoardFieldHeight;
  if TryPos.Y >= BoardHeight then Exit(false);

  BoardPos := TryPos;
  result := true;
end;

function TMyView.Motion(const Event: TInputMotion): Boolean;
var NewHighlightOneBF: boolean;
    NewHighlightOneBFPos, BoardPos: TVector2Integer;
    NewHighlightWay: boolean;
    NewHighlightWayPos: TVector2Integer;
begin
  Result := inherited;
  if Result then Exit;

 NewHighlightOneBF := false;
 NewHighlightWay := false;

 if (Action = paMove) and (MoveState = msNone) and
   MousePosToBoard(Event.Position, BoardPos) then
 begin
  NewHighlightOneBFPos := BoardPos;
  NewHighlightOneBF := true;
 end else
 if (Action = paMove) and (MoveState = msSourceSelected) and
   MousePosToBoard(Event.Position, BoardPos) then
 begin
  NewHighlightWayPos := BoardPos;
  NewHighlightWay := true;
 end;

 { zrob Invalidate tylko jesli w New* cos sie zmienilo. W zasadzie
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
  Window.Invalidate;
 end;
end;

function TMyView.Press(const Event: TInputPressRelease): Boolean;

  {$ifdef LINUX} procedure Beep; begin Write(#7) end; {$endif}

var
  BoardPos: TVector2Integer;
  RectangleIndex: Integer;
  GLImage: TDrawableImage;
begin
  Result := inherited;
  if Result then Exit;

  if Event.IsMouseButton(buttonLeft) then
  begin
    if (Action = paMove) and (MoveState = msNone) and
      MousePosToBoard(Container.MousePosition, BoardPos) and
      (Board[BoardPos.X, BoardPos.Y] <> bfEmpty) then
    begin
      MoveState := msSourceSelected;
      Move.A := BoardPos;
      Window.Invalidate;
    end else
    if (Action = paMove) and (MoveState = msSourceSelected) and
      MousePosToBoard(Container.MousePosition, BoardPos) then
    begin
      { jezeli kliknal na pustym to znaczy ze wybiera target.
        Wpp. znaczy ze wybiera ponownie source. }
      if Board[BoardPos.X, BoardPos.Y] = bfEmpty then
      begin
        if CWayOnTheBoard(Move.A, BoardPos) then
        begin
          MoveState := msTargetSelected;
          Move.B := BoardPos;
          MoveWay.Count := 0;
          MoveWay.AddRange(CWayResultWay);
        end else
          { bardziej jasny komunikat, w rodzaju MessageOK(Window, 'No way found'),
            nie jest tu potrzebny bo podswietlamy droge z A do B wiec user i tak
            widzi ze nie ma drogi; po prostu przypadkiem kliknal sobie tutaj. }
          Beep;
      end else
        Move.A := BoardPos;
      Window.Invalidate;
    end else
    begin
      { obslugujemy klikanie myszka na przyciskach ponizej }
      RectangleIndex := ButtonsRects.FindRectangle(Container.MousePosition);
      case RectangleIndex of
        0: Window.Container.EventPress(InputKey(Container.MousePosition, keyF1, #0, []));
        1: Window.Container.EventPress(InputKey(Container.MousePosition, keyNone, 'i', []));
        2: Window.Container.EventPress(InputKey(Container.MousePosition, keyNone, 's', []));
        3: Window.Container.EventPress(InputKey(Container.MousePosition, keyNone, 'n', []));
        4: Window.Container.EventPress(InputKey(Container.MousePosition, keyNone, 'r', []));
      end;
    end;
  end else
  if Event.EventType = itKey then
  begin
    case Event.Key of
     keyF1: ShowHelp;
     else
      case Event.KeyCharacter of
       'r':
         if MessageYesNo(Window, 'End this game and start another one ?') then
          Action := paNewGame;
       CharEscape: AskQuit(Window);
       'h':
         begin
          DrawGame;
          DrawHighscores;
          { directly get screenshot now, without redrawing with Window.OnRender }
          GLImage := SaveScreenToGL_NoFlush(Window.Rect, Window.SaveScreenBuffer);
          try
            InputAnyKey(GLImage, 0, 0, Window.Width, Window.Height);
          finally FreeAndNil(GLImage) end;
         end;
       'n': ShowNextColors := not ShowNextColors;
       'i': BallsImageSet := ChangeIntCycle(BallsImageSet, 1, High(BallsImageSet));
       's': AllowSpecialBalls := not AllowSpecialBalls;
       else Exit;
      end;
    end;

    Window.Invalidate;
  end;
end;

{ zasadnicze GetPlayerMove ------------------------------------------------- }

function GetPlayerAction(var PlayerMove: TPlayerMove;
  PlayerMoveWay: TVector2IntegerList): TPlayerAction;
var
  View: TMyView;
  SavedMode: TGLMode;
begin
  View := TMyView.Create(nil);
  try
    SavedMode := TGLMode.CreateReset(Window);
    try
      CWayClearCache;
      HighlightOneBF := false;
      HighlightWay := false;
      MoveState := msNone;
      Action := paMove;

      Window.Container.PushView(View);
      repeat
        Application.ProcessMessage(true, true);
      until (Action <> paMove) or (MoveState = msTargetSelected);
      Window.Container.PopView(View);

      result := Action;
      if result = paMove then
      begin
        PlayerMove := Move;
        if PlayerMoveWay <> nil then
        begin
          PlayerMoveWay.Count := 0;
          PlayerMoveWay.AddRange(MoveWay);
        end;
      end;
    finally SavedMode.Free end;
  finally View.Free end;
end;

{ glw open/close --------------------------------------------------------- }

procedure ContextOpen;
begin
 { dopiero w OpenGL inicjuj Rectangles, na wypadek gdybym kiedys zrobil odczytywanie
   ImgButtonWidth/Height z pliku dopiero w RenderingGame.ContextOpen. }
 ButtonsRects.Add(Rectangle( 20, StatusButtonsY, ImgButtonWidth, ImgButtonHeight));
 ButtonsRects.Add(Rectangle(120, StatusButtonsY, ImgButtonWidth, ImgButtonHeight));
 ButtonsRects.Add(Rectangle(256, StatusButtonsY, ImgButtonWidth, ImgButtonHeight));
 ButtonsRects.Add(Rectangle(409, StatusButtonsY, ImgButtonWidth, ImgButtonHeight));
 ButtonsRects.Add(Rectangle(509, StatusButtonsY, ImgButtonWidth, ImgButtonHeight));
end;

initialization
 ApplicationProperties.OnGLContextOpen.Add(@ContextOpen);
 MoveWay := TVector2IntegerList.Create;
 ButtonsRects := TRectangleList.Create;
 Theme.ImagesPersistent[tiActiveFrame].Image := FrameYellow;
 Theme.ImagesPersistent[tiActiveFrame].OwnsImage := false;
 Theme.ImagesPersistent[tiActiveFrame].ProtectedSides.AllSides := 0;
finalization
 FreeAndNil(MoveWay);
 FreeAndNil(ButtonsRects);
end.
