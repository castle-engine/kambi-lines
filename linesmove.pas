{
  Copyright 2003-2013 Michalis Kamburelis.

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

unit LinesMove;

interface

uses LinesBoard, GetPlayerActionUnit, CastleVectors;

{ przemieszcza kulke na Board zgodnie z Move. Wykonuje animacje kulki
  wedrujacej wzdluz MoveWay. Wiec zadane Move musi byc poprawne z droga
  MoveWay. }
procedure BallMove(const Move: TPlayerMove; MoveWay: TVector2IntegerList);

implementation

uses GL, GLU, GLExt, CastleWindow, CastleGLUtils, CastleWindowModes, CastleUtils, Math, DrawingGame,
  LinesWindow, LinesGame, CastleTimeUtils, CastleGLImages, SysUtils;

procedure BallMove(const Move: TPlayerMove; MoveWay: TVector2IntegerList);
var
  BF: TNonEmptyBF;
  SavedMode: TGLMode;
  BoardImage: TGLImage;
  Position: Single;
  Ball: TVector2Single;
  Pos1: Integer;
  CompSpeed: Single;
  RenderStartTime: TTimerResult;
begin
  BF := Board[Move.A[0], Move.A[1]];
  Board[Move.A[0], Move.A[1]] := bfEmpty;
  DrawGame;
  BoardImage := SaveScreenToGL_noflush(0, 0, Window.Width, Window.Height, GL_BACK);
  try
    SavedMode := TGLMode.CreateReset(Window, GL_COLOR_BUFFER_BIT, false,
      nil, nil, @NoClose);
    try
      glAlphaFunc(GL_GREATER, 0.5);

      { Dobra, teraz robimy animacje w OpenGLu przesuwajacej sie kulki.
        Najwazniejsza rzecza tutaj jest zmienna Position : przybiera ona
        wartosci od 0 do Way.Count. Wartosc 0 oznacza ze kulka jest na pozycji
        X1, Y1, wartosci i = 1..Way.Count oznaczaja ze kulka jest na pozycji Way[i].
        Wartosci rzeczywiste pomiedzy to interpolacja tych pozycji. }
      Position := 0;
      while Position < MoveWay.Count do
      begin
        RenderStartTime := Timer;

        { draw animation frame }
        glRasterPos2i(ScreenX0, ScreenY0);
        BoardImage.Draw;

        if Position <= 1 then
          Ball := Lerp(Position, Move.A, MoveWay.L[0]) else
        begin
          { Max ponizej jest zeby miec absolutna pewnosc ze otrzymane Pos1 jest
            indeksem w zakresie 1..Way.Count-1, bez wzgledu na bledy zmiennoprzec. }
          Pos1 := Clamped(Floor(Position), 1, MoveWay.Count-1);
          Ball := Lerp(Position-Pos1, MoveWay.L[Pos1-1], MoveWay.L[Pos1]);
        end;

        glRasterPos2f(BoardFieldImage0X + BoardFieldWidth * Ball[0],
                      BoardFieldImage0Y + BoardFieldHeight * Ball[1]);
        { TODO: glenable/disable below should be in disp list }
        glEnable(GL_ALPHA_TEST);
        NonEmptyBFImages[BallsImageSet, BF].Draw;
        glDisable(GL_ALPHA_TEST);

        { OnDraw nie ma, wiec nie zrobi nic. FlushRedisplay zrobi tylko swap buffers
          na dotychczasowej zawartosci ekranu. }
        Window.PostRedisplay;
        Window.FlushRedisplay;

        { We're not inside Idle, so Window.Fps.IdleSpeed is not available.
          So we just calculate CompSpeed ourselves below. }
        CompSpeed := (Timer - RenderStartTime) / TimerFrequency;

        Position += 10 * CompSpeed;
      end;

      { zakoncz animacje, przenies kulke na koncowa pozycje w Board[] }
      Board[Move.B[0], Move.B[1]] := BF;
    finally FreeAndNil(SavedMode) end;
  finally FreeAndNil(BoardImage) end;
end;

end.
