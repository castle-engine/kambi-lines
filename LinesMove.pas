{
  Copyright 2003-2007 Michalis Kamburelis.

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

unit LinesMove;

interface

uses LinesBoard, GetPlayerActionUnit, VectorMath;

{ przemieszcza kulke na Board zgodnie z Move. Wykonuje animacje kulki
  wedrujacej wzdluz MoveWay. Wiec zadane Move musi byc poprawne z droga
  MoveWay. }
procedure BallMove(const Move: TPlayerMove; MoveWay: TDynVector2IntegerArray);

implementation

uses GL, GLU, GLExt, GLWindow, KambiGLUtils, GLWinModes, KambiUtils, Math, DrawingGame,
  LinesWindow, LinesGame, KambiTimeUtils, GLImages;

procedure BallMove(const Move: TPlayerMove; MoveWay: TDynVector2IntegerArray);
var
  BF: TNonEmptyBF;
  SavedMode: TGLMode;
  dlBoardImage: TGLuint;
  Position: Single;
  Ball: TVector2Single;
  Pos1: Integer;
  CompSpeed: Single;
  RenderStartTime: TKamTimerResult;
begin
  BF := Board[Move.A[0], Move.A[1]];
  Board[Move.A[0], Move.A[1]] := bfEmpty;
  DrawGame;
  dlBoardImage := SaveScreenToDisplayList_noflush(GL_BACK);
  try
    SavedMode := TGLMode.Create(glw, GL_COLOR_BUFFER_BIT, false);
    try
      SetStdNoCloseGLWindowState(glw, nil, nil, nil, false, true, false, K_None,
        false, false);

      glAlphaFunc(GL_GREATER, 0.5);

      { Dobra, teraz robimy animacje w OpenGLu przesuwajacej sie kulki.
        Najwazniejsza rzecza tutaj jest zmienna Position : przybiera ona
        wartosci od 0 do Way.Length. Wartosc 0 oznacza ze kulka jest na pozycji
        X1, Y1, wartosci i = 1..Way.Length oznaczaja ze kulka jest na pozycji Way[i].
        Wartosci rzeczywiste pomiedzy to interpolacja tych pozycji. }
      Position := 0;
      while Position < MoveWay.Length do
      begin
        RenderStartTime := KamTimer;

        { draw animation frame }
        glRasterPos2i(ScreenX0, ScreenY0);
        glCallList(dlBoardImage);

        if Position <= 1 then
          Ball := Lerp(Position, Move.A, MoveWay.Items[0]) else
        begin
          { Max ponizej jest zeby miec absolutna pewnosc ze otrzymane Pos1 jest
            indeksem w zakresie 1..Way.Length-1, bez wzgledu na bledy zmiennoprzec. }
          Pos1 := Clamped(Floor(Position), 1, MoveWay.Length-1);
          Ball := Lerp(Position-Pos1, MoveWay.Items[Pos1-1], MoveWay.Items[Pos1]);
        end;

        glRasterPos2f(BoardFieldImage0X + BoardFieldWidth * Ball[0],
                      BoardFieldImage0Y + BoardFieldHeight * Ball[1]);
        { TODO: glenable/disable below should be in disp list }
        glEnable(GL_ALPHA_TEST);
        glCallList(dlNonEmptyBFImages[BallsImageSet, BF]);
        glDisable(GL_ALPHA_TEST);

        { OnDraw nie ma, wiec nie zrobi nic. FlushRedisplay zrobi tylko swap buffers
          na dotychczasowej zawartosci ekranu. }
        glw.PostRedisplay;
        glw.FlushRedisplay;

        { We shouldn't use Glw.FPSCompSpeed, because we tricked the drawing and
          OnDraw was nil. So Glw.FPSCompSpeed would indicate that computer speed was huge,
          while in fact we just did the drawing outside OnDraw...
          So we calculate CompSpeed ourselves below. }
        CompSpeed := ((KamTimer - RenderStartTime) / KamTimerFrequency) * 50;

        Position += 0.2 * CompSpeed;
      end;

      { zakoncz animacje, przenies kulke na koncowa pozycje w Board[] }
      Board[Move.B[0], Move.B[1]] := BF;
    finally SavedMode.Free end;
  finally glDeleteLists(dlBoardImage, 1) end;
end;

end.
