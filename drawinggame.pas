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

unit DrawingGame;

{ Zalezy od LinesBoard, LinesGame. NIE zalezy od GetPlayerMove i LinesMove. }

interface

uses GL, CastleGLUtils, VectorMath, LinesGame, LinesBoard;

{ rysuje cala plansze gry (zajmujac cala powierzchnie window, nie tylko
  GameScreen). Stan Board, PlayerScore, NextColors i inne sa tutaj pokazywane.
  Podswietla pola HighlightOneBFPos (o ile HighlightOneBF)
  i HighlightBFs (o ile HighlightBFs <> nil). }
procedure DrawGame(HighlightOneBF: boolean; const HighlightOneBFPos: TVector2Integer;
  HighlightBFs: TVector2IntegerList); overload;
procedure DrawGame; overload;

const
  { wartosci ponizej zsynchronizowane z game.png }
  BoardField0X = 171;
  BoardField0Y = 73;
  BoardFieldWidth = 34;
  BoardFieldHeight = 24;

  { BoardFieldImageShiftX mowi jak trzeba przesunac pozycje
    (wzgledem pozycji obliczonej w/g BoardField0X + i * BoardFieldWidth)
    zeby narysowac na tej pozycji kuleczke, tzn. zeby uzyc dlNonEmptyBFImages. }
  BoardFieldImageShiftX = 3;
  BoardFieldImageShiftY = 3;
  BoardFieldImage0X = BoardField0X + BoardFieldImageShiftX;
  BoardFieldImage0Y = BoardField0Y + BoardFieldImageShiftY;

  { zsynchronizowane z button.png. W interfejsie, bo uzywane tez w GetPlayerActionUnit. }
  ImgButtonWidth = 31;
  ImgButtonHeight = 25;
  StatusButtonsY = 8;

{ Balls zaladowane do display list OpenGLa. W interfejsie, bo przydatne takze
  w LinesMove. Jako pierwszego indeksu bedziesz chcial zazwyczaj uzywac
  BallsImageSet. }
var dlNonEmptyBFImages: array[TBallsImageSet, TNonEmptyBF]of TGLuint;

implementation

uses SysUtils, LinesWindow, CastleWindow, Images, UIControls,
  HighscoresUnit, CastleUtils, OpenGLBmpFonts, BFNT_ChristmasCard_m24_Unit,
  BFNT_BitstreamVeraSans_Bold_m14_Unit, GLImages;

var
  dlGameImage, dlColrowImage,
    dlMasterImage, dlPretenderImage, dlMasterAltImage, dlPretenderAltImage,
    dlHighlightOneBFImage,
    dlButtonImage, dlFrameLImage, dlFrameMImage, dlFrameRImage: TGLuint;
  ButtonCaptionFont, PlayerNamesFont: TGLBitmapFont;

procedure DrawGame(HighlightOneBF: boolean; const HighlightOneBFPos: TVector2Integer;
  HighlightBFs: TVector2IntegerList);
const
  { pozycje zsynchronizowane z game.png }
  ColrowY0 = 119;
  MasterColrowX0 = 58;
  MasterImageX0 = 52;
  PretenderColrowX0 = 532;
  PretenderImageX0 = 517;

  NextColorsImage0X = 276;
  NextColorsImage0Y = 324;
  NextColorsFieldWidth = BoardFieldWidth;

  StatusUpTextY = 329;
  PlayerNamesY = 80;

  ImgGameWidth = 640;
  ImgGameHeight = 350;

  { stale dla colrows, luzno zwiazane z game.png.
    W oryginalnych kulkach Max jest chyba 22 a Min - tak jakby 1.5
    (ich colrow jest chyba naszym colrowem odwroconym, tzn. pierwsze dwa wiersze
    naszego colrowa sa drugimi dwoma wierszami ich colrowa; a moze po prostu
    maja tam wieksza podstawe kolumienki w game.png ? Nie wiem juz teraz,
    ale to nie jest takie wazne; nie chce mi sie synchronizowac kolumienek
    na game.png, colrow.png i master/pretender[_alt].png od nowa.)
    Moj zakres jest wiec troche wiekszy i podoba mi sie to. }
  MaxColrowCount = 24;
  MinColrowCount = 1;

  { zsynchronizowane z odpowiednimi obrazkami }
  ImgColrowWidth = 45;
  ImgColrowHeight = 4;
  ImgFrameLWidth = 7;
  ImgFrameRWidth = 6;
  ImgFrameHeight = 21;

  procedure DisplayColumn(ColrowCount, ColrowX0, TopImageX0: integer;
    dlTopImage: TGLuint);
  var i: integer;
  begin
   for i := 0 to ColrowCount-1 do
   begin
    glRasterPos2i(ColrowX0, ColrowY0 + i*ImgColrowHeight);
    glCallList(dlColrowImage);
   end;
   glRasterPos2i(TopImageX0, ColrowY0 + ColrowCount*ImgColrowHeight);
   glCallList(dlTopImage);
  end;

  procedure Highlight(BF: TVector2Integer);
  begin
   glRasterPos2i(BoardField0X + BoardFieldWidth * BF[0],
                 BoardField0Y + BoardFieldHeight * BF[1]);
   glCallList(dlHighlightOneBFImage);
  end;

  procedure DrawText(x, y: Integer; const s: string; const Color: TVector3Byte);
  begin
   glColorv(Color);
   glRasterPos2i(x, y);
   LinesFont.Print(s);
  end;

  procedure DrawTextRPad(x, y: Integer; const s: string; const Color: TVector3Byte);
  begin
   DrawText(x-LinesFont.TextWidth(s), y, s, Color);
  end;

  procedure DrawPlayerName(const s: string; MiddleX: Integer);
  var x: Integer;
  begin
   { jezeli PlayerNamesFont.TextWidth(s) to x := 0. Nie bedzie to zbyt ladne,
     ale przynajmniej bedzie cos widac. }
   x := Max(MiddleX - PlayerNamesFont.TextWidth(s) div 2, 0);
   glColor3ub(255, 255, 255);
   glRasterPos2i(x, PlayerNamesY);
   PlayerNamesFont.PrintAndMove(s);
  end;

var ButtonsAndFramesX: Integer;

  procedure DrawButton(y: Integer; const s: string);
  begin
   glRasterPos2i(ButtonsAndFramesX, y);
   glCallList(dlButtonImage);
   glColor3ub(0, 0, 0);
   glRasterPos2i(ButtonsAndFramesX + (ImgButtonWidth -
     ButtonCaptionFont.TextWidth(s)) div 2, y+7);
   ButtonCaptionFont.Print(s);
   ButtonsAndFramesX += ImgButtonWidth;
  end;

  procedure DrawFrame(const y: Integer; const s: string; const FrameTextColor: TVector3Byte);
  const CaptionHorizMargin = 6;
  var x0, i: Integer;
  begin
   x0 := ButtonsAndFramesX;
   glRasterPos2i(ButtonsAndFramesX, y);
   glCallList(dlFrameLImage);
   ButtonsAndFramesX += ImgFrameLWidth;
   for i := 0 to LinesFont.TextWidth(s) + CaptionHorizMargin*2 do
   begin
    glRasterPos2i(ButtonsAndFramesX, y);
    glCallList(dlFrameMImage);
    Inc(ButtonsAndFramesX);
   end;
   glRasterPos2i(ButtonsAndFramesX, y);
   glCallList(dlFrameRImage);
   ButtonsAndFramesX += ImgFrameRWidth;

   DrawText(x0+ImgFrameLWidth + CaptionHorizMargin, y+6, s, FrameTextColor);
  end;

  procedure DrawButtonAndFrame(const y: Integer;
    const ButCaption, FrameCaption: string; const FrameTextColor: TVector3Byte);
  begin
   DrawButton(y, ButCaption);
   ButtonsAndFramesX += 4;
   DrawFrame(y + (ImgButtonHeight - ImgFrameHeight) div 2, FrameCaption, FrameTextColor);
   ButtonsAndFramesX += 10;
  end;

  const
    { w oryginalnych kulkach TextColors = TextOnOff[false], TextScoreColor =
      TextOnOff[true] ale dla mnie TextOnOff[false] jest za ciemny a w ogole
      to inne teksty nie powinny miec takich kolorow zeby user widzial ze to
      nie sa teksty ktore reprezentuja cos co mozna wlaczyc/wylaczyc. }
    TextOnOffColors: array[boolean]of TVector3Byte = ((84, 84, 84), (0, 168, 0));
    TextColor: TVector3Byte = (230, 230, 230);
    TextScoreColor: TVector3Byte = (230, 230, 230);

var i, j: Integer;
begin
 if (Window.Width > GameScreenWidth) or (Window.Height > GameScreenHeight) then
  glClear(GL_COLOR_BUFFER_BIT);

 glRasterPos2i(0, 0);
 glCallList(dlGameImage);

 { wyswietlaj kolumny odzwierciedlajace punkty gracza w stosunku do
   punktow krola. Ten kto ma wiecej jest na wysokosci MaxColrowCount,
   ten drugi jest na takiej wysokosci pomiedzy Min a MaxColrowCount
   gdzie sa jego punkty pomiedzy zerem a punktami pierwszego.
   Round() jest otoczone przez Clamped aby uniknac wszelkiego ryzyka
   zwiazanego z operacjami na liczbach zmiennoprzec. }
 if KingScore^.Score >= PlayerScore then
 begin
  DisplayColumn(MaxColrowCount, MasterColrowX0, MasterImageX0, dlMasterImage);
  DisplayColumn(
    Clamped(Round(Lerp(PlayerScore/KingScore^.Score, MinColrowCount, MaxColrowCount)),
      MinColrowCount, MaxColrowCount),
    PretenderColrowX0, PretenderImageX0, dlPretenderImage);
 end else
 begin
  DisplayColumn(
    Clamped(Round(Lerp(KingScore^.Score/PlayerScore, MinColrowCount, MaxColrowCount)),
      MinColrowCount, MaxColrowCount),
    MasterColrowX0, MasterImageX0, dlMasterAltImage);
  DisplayColumn(maxColrowCount, PretenderColrowX0, PretenderImageX0, dlPretenderAltImage);
 end;

 if HighlightOneBF then
  Highlight(HighlightOneBFPos);
 if HighlightBFs <> nil then
  for i := 0 to HighlightBFs.Count-1 do Highlight(HighlightBFs.Items[i]);

 glAlphaFunc(GL_GREATER, 0.5);
 glEnable(GL_ALPHA_TEST);
 try
  for i := 0 to BoardWidth-1 do
   for j := 0 to BoardHeight-1 do
    if Board[i, j] <> bfEmpty then
    begin
     glRasterPos2i(BoardFieldImage0X + BoardFieldWidth*i,
                   BoardFieldImage0Y + BoardFieldHeight*j);
     glCallList(dlNonEmptyBFImages[BallsImageSet, Board[i, j]]);
    end;
  if ShowNextColors then
   for i := 0 to NextColorsCount-1 do
   begin
    glRasterPos2i(NextColorsImage0X + NextColorsFieldWidth*i, NextColorsImage0Y);
    glCallList(dlNonEmptyBFImages[BallsImageSet, NextColors[i]]);
   end;
 finally glDisable(GL_ALPHA_TEST) end;

 ButtonsAndFramesX := 20;
 { TODO: zmieniajac ponizsze musze tez zmienic generowanie Areas w
   GetPlayerActionUnit.}
 DrawButtonAndFrame(StatusButtonsY, 'F1', 'Help', TextColor);
 DrawButtonAndFrame(StatusButtonsY, 'I', 'Image Set', TextColor);
 DrawButtonAndFrame(StatusButtonsY, 'S', 'Special balls', TextOnOffColors[AllowSpecialBalls]);
 DrawButtonAndFrame(StatusButtonsY, 'N', 'Next', TextOnOffColors[ShowNextColors]);
 DrawButtonAndFrame(StatusButtonsY, 'R', 'Restart', TextColor);

 DrawTextRPad(120, StatusUpTextY, IntToStr(KingScore^.Score), TextScoreColor);
 DrawTextRPad(570, StatusUpTextY, IntToStr(PlayerScore), TextScoreColor);

 if BonusScoreMultiplier > 1 then
  DrawText(18, 45, 'ACTIVE BONUS: x '+IntToStr(BonusScoreMultiplier), Vector3Byte(100, 255, 100));

 DrawPlayerName(KingScore^.PlayerName, 80);
 DrawPlayerName('Pretender', 555);
end;

procedure DrawGame;
const DummyBoardPos: TVector2Integer = (0, 0);
begin
 DrawGame(false, DummyBoardPos, nil);
end;

{ glw open/close --------------------------------------------------------- }

procedure WindowOpen(const Container: IUIContainer);
const
  NonEmptyBFImageFileNames: array[TNonEmptyBF]of string=
  ('ball_brown', 'ball_yellow', 'ball_green', 'ball_white',
   'ball_violet', 'ball_red', 'ball_blue',
   'ball_blue_yellow', 'ball_red_white', 'ball_joker');
var bf: TNonEmptyBF;
    i: Integer;
begin
 dlGameImage := LoadImageToDisplayList(ImagesPath +'game.png', [TRGBImage], [], 0, 0);
 dlColrowImage := LoadImageToDisplayList(ImagesPath +'colrow.png', [TRGBImage], [], 0, 0);
 dlMasterImage := LoadImageToDisplayList(ImagesPath +'master.png', [TRGBImage], [], 0, 0);
 dlPretenderImage := LoadImageToDisplayList(ImagesPath +'pretender.png', [TRGBImage], [], 0, 0);
 dlMasterAltImage := LoadImageToDisplayList(ImagesPath +'master_alt.png', [TRGBImage], [], 0, 0);
 dlPretenderAltImage := LoadImageToDisplayList(ImagesPath +'pretender_alt.png', [TRGBImage], [], 0, 0);
 dlHighlightOneBFImage := LoadImageToDisplayList(ImagesPath +'bf_highlight.png', [TRGBImage], [], 0, 0);
 dlButtonImage := LoadImageToDisplayList(ImagesPath +'button.png', [TRGBImage], [], 0, 0);
 dlFrameLImage := LoadImageToDisplayList(ImagesPath +'frame_l.png', [TRGBImage], [], 0, 0);
 dlFrameMImage := LoadImageToDisplayList(ImagesPath +'frame_m.png', [TRGBImage], [], 0, 0);
 dlFrameRImage := LoadImageToDisplayList(ImagesPath +'frame_r.png', [TRGBImage], [], 0, 0);

 for i := 0 to High(TBallsImageSet) do
  for bf := LowNonEmptyBF to HighNonEmptyBF do
   dlNonEmptyBFImages[i, bf] := LoadImageToDisplayList(ImagesPath +
     NonEmptyBFImageFileNames[bf]+'_'+IntToStr(i)+'.png',
       [TRGBAlphaImage], [], 0, 0);

 PlayerNamesFont := TGLBitmapFont.Create(@BFNT_ChristmasCard_m24);
 ButtonCaptionFont := TGLBitmapFont.Create(@BFNT_BitstreamVeraSans_Bold_m14);
end;

procedure WindowClose(const Container: IUIContainer);
begin
 PlayerNamesFont.Free;
 ButtonCaptionFont.Free;
end;

initialization
 OnGLContextOpen.Add(@WindowOpen);
 OnGLContextClose.Add(@WindowClose);
finalization
end.
