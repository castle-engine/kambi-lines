{
  Copyright 2003-2016 Michalis Kamburelis.

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

uses CastleGLUtils, CastleVectors, LinesGame, LinesBoard, CastleGLImages;

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
    zeby narysowac na tej pozycji kuleczke, tzn. zeby uzyc NonEmptyBFImages. }
  BoardFieldImageShiftX = 3;
  BoardFieldImageShiftY = 3;
  BoardFieldImage0X = BoardField0X + BoardFieldImageShiftX;
  BoardFieldImage0Y = BoardField0Y + BoardFieldImageShiftY;

  { zsynchronizowane z button.png. W interfejsie, bo uzywane tez w GetPlayerActionUnit. }
  ImgButtonWidth = 31;
  ImgButtonHeight = 25;
  StatusButtonsY = 8;

{ Balls images, with alpha test. The first array index usually comes from
  BallsImageSet. }
var NonEmptyBFImages: array [TBallsImageSet, TNonEmptyBF] of TGLImage;

implementation

uses SysUtils, LinesWindow, CastleWindow, CastleImages, CastleUIControls,
  HighscoresUnit, CastleUtils, CastleColors, CastleControls,
  CastleApplicationProperties;

var
  GameImage,
  ColrowImage,
  MasterImage,
  PretenderImage,
  MasterAltImage,
  PretenderAltImage,
  HighlightOneBFImage,
  ButtonImage,
  FrameLImage,
  FrameMImage,
  FrameRImage: TGLImage;

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
    TopImage: TGLImage);
  var i: integer;
  begin
   for i := 0 to ColrowCount-1 do
     ColrowImage.Draw(ColrowX0, ColrowY0 + i*ImgColrowHeight);
   TopImage.Draw(TopImageX0, ColrowY0 + ColrowCount*ImgColrowHeight);
  end;

  procedure Highlight(BF: TVector2Integer);
  begin
   HighlightOneBFImage.Draw(
     BoardField0X + BoardFieldWidth * BF[0],
     BoardField0Y + BoardFieldHeight * BF[1]);
  end;

  procedure DrawText(x, y: Integer; const s: string; const Color: TCastleColor);
  begin
   UIFontSmall.Print(X, Y, Color, s);
  end;

  procedure DrawTextRPad(x, y: Integer; const s: string; const Color: TCastleColor);
  begin
   DrawText(x-UIFontSmall.TextWidth(s), y, s, Color);
  end;

  procedure DrawPlayerName(const s: string; MiddleX: Integer);
  var x: Integer;
  begin
   { jezeli PlayerNamesFont.TextWidth(s) to x := 0. Nie bedzie to zbyt ladne,
     ale przynajmniej bedzie cos widac. }
   x := Max(MiddleX - UIFont.TextWidth(s) div 2, 0);
   UIFont.Print(x, PlayerNamesY, White, s);
  end;

var ButtonsAndFramesX: Integer;

  procedure DrawButton(y: Integer; const s: string);
  begin
   ButtonImage.Draw(ButtonsAndFramesX, y);
   UIFontSmall.Print(ButtonsAndFramesX + (ImgButtonWidth -
     UIFontSmall.TextWidth(s)) div 2, y+7, Black, s);
   ButtonsAndFramesX += ImgButtonWidth;
  end;

  procedure DrawFrame(const y: Integer; const s: string; const FrameTextColor: TCastleColor);
  const CaptionHorizMargin = 6;
  var x0, i: Integer;
  begin
   x0 := ButtonsAndFramesX;
   FrameLImage.Draw(ButtonsAndFramesX, y);
   ButtonsAndFramesX += ImgFrameLWidth;
   for i := 0 to UIFontSmall.TextWidth(s) + CaptionHorizMargin*2 do
   begin
    FrameMImage.Draw(ButtonsAndFramesX, y);
    Inc(ButtonsAndFramesX);
   end;
   FrameRImage.Draw(ButtonsAndFramesX, y);
   ButtonsAndFramesX += ImgFrameRWidth;

   DrawText(x0+ImgFrameLWidth + CaptionHorizMargin, y+6, s, FrameTextColor);
  end;

  procedure DrawButtonAndFrame(const y: Integer;
    const ButCaption, FrameCaption: string; const FrameTextColor: TCastleColor);
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
  TextOnOffColors: array [boolean] of TCastleColor = (
    (84/255, 84/255, 84/255, 255/255),
    (0/255, 168/255, 0/255, 255/255));
  TextColor: TCastleColor = (230/255, 230/255, 230/255, 255/255);
  TextScoreColor: TCastleColor = (230/255, 230/255, 230/255, 255/255);

var i, j: Integer;
begin
 if (Window.Width > GameScreenWidth) or (Window.Height > GameScreenHeight) then
  GLClear([cbDepth], Black);

 GameImage.Draw(0, 0);

 { wyswietlaj kolumny odzwierciedlajace punkty gracza w stosunku do
   punktow krola. Ten kto ma wiecej jest na wysokosci MaxColrowCount,
   ten drugi jest na takiej wysokosci pomiedzy Min a MaxColrowCount
   gdzie sa jego punkty pomiedzy zerem a punktami pierwszego.
   Round() jest otoczone przez Clamped aby uniknac wszelkiego ryzyka
   zwiazanego z operacjami na liczbach zmiennoprzec. }
 if KingScore^.Score >= PlayerScore then
 begin
  DisplayColumn(MaxColrowCount, MasterColrowX0, MasterImageX0, MasterImage);
  DisplayColumn(
    Clamped(Round(Lerp(PlayerScore/KingScore^.Score, MinColrowCount, MaxColrowCount)),
      MinColrowCount, MaxColrowCount),
    PretenderColrowX0, PretenderImageX0, PretenderImage);
 end else
 begin
  DisplayColumn(
    Clamped(Round(Lerp(KingScore^.Score/PlayerScore, MinColrowCount, MaxColrowCount)),
      MinColrowCount, MaxColrowCount),
    MasterColrowX0, MasterImageX0, MasterAltImage);
  DisplayColumn(maxColrowCount, PretenderColrowX0, PretenderImageX0, PretenderAltImage);
 end;

 if HighlightOneBF then
  Highlight(HighlightOneBFPos);
 if HighlightBFs <> nil then
  for i := 0 to HighlightBFs.Count-1 do Highlight(HighlightBFs.Items[i]);

 for i := 0 to BoardWidth-1 do
  for j := 0 to BoardHeight-1 do
   if Board[i, j] <> bfEmpty then
   begin
    NonEmptyBFImages[BallsImageSet, Board[i, j]].Draw(
      BoardFieldImage0X + BoardFieldWidth*i,
      BoardFieldImage0Y + BoardFieldHeight*j);
   end;

 if ShowNextColors then
  for i := 0 to NextColorsCount-1 do
  begin
   NonEmptyBFImages[BallsImageSet, NextColors[i]].Draw(
     NextColorsImage0X + NextColorsFieldWidth*i, NextColorsImage0Y)
  end;

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
  DrawText(18, 45, 'ACTIVE BONUS: x '+IntToStr(BonusScoreMultiplier),
    Vector4Single(0.4, 1.0, 0.4, 1.0));

 DrawPlayerName(KingScore^.PlayerName, 80);
 DrawPlayerName('Pretender', 555);
end;

procedure DrawGame;
const DummyBoardPos: TVector2Integer = (0, 0);
begin
 DrawGame(false, DummyBoardPos, nil);
end;

{ glw open/close --------------------------------------------------------- }

procedure ContextOpen;
const
  NonEmptyBFImageNames: array[TNonEmptyBF]of string=
  ('ball_brown', 'ball_yellow', 'ball_green', 'ball_white',
   'ball_violet', 'ball_red', 'ball_blue',
   'ball_blue_yellow', 'ball_red_white', 'ball_joker');
var
  bf: TNonEmptyBF;
  i: Integer;
begin
 GameImage := TGLImage.Create(ImagesPath +'game.png', [TRGBImage]);
 ColrowImage := TGLImage.Create(ImagesPath +'colrow.png', [TRGBImage]);
 MasterImage := TGLImage.Create(ImagesPath +'master.png', [TRGBImage]);
 PretenderImage := TGLImage.Create(ImagesPath +'pretender.png', [TRGBImage]);
 MasterAltImage := TGLImage.Create(ImagesPath +'master_alt.png', [TRGBImage]);
 PretenderAltImage := TGLImage.Create(ImagesPath +'pretender_alt.png', [TRGBImage]);
 HighlightOneBFImage := TGLImage.Create(ImagesPath +'bf_highlight.png', [TRGBImage]);
 ButtonImage := TGLImage.Create(ImagesPath +'button.png', [TRGBImage]);
 FrameLImage := TGLImage.Create(ImagesPath +'frame_l.png', [TRGBImage]);
 FrameMImage := TGLImage.Create(ImagesPath +'frame_m.png', [TRGBImage]);
 FrameRImage := TGLImage.Create(ImagesPath +'frame_r.png', [TRGBImage]);

 for i := 0 to High(TBallsImageSet) do
  for bf := LowNonEmptyBF to HighNonEmptyBF do
  begin
   NonEmptyBFImages[i, bf] := TGLImage.Create(ImagesPath +
     NonEmptyBFImageNames[bf]+'_'+IntToStr(i)+'.png', [TRGBAlphaImage]);
   NonEmptyBFImages[i, bf].Alpha := acTest;
  end;
end;

procedure ContextClose;
var
  bf: TNonEmptyBF;
  i: Integer;
begin
 FreeAndNil(GameImage);
 FreeAndNil(ColrowImage);
 FreeAndNil(MasterImage);
 FreeAndNil(PretenderImage);
 FreeAndNil(MasterAltImage);
 FreeAndNil(PretenderAltImage);
 FreeAndNil(HighlightOneBFImage);
 FreeAndNil(ButtonImage);
 FreeAndNil(FrameLImage);
 FreeAndNil(FrameMImage);
 FreeAndNil(FrameRImage);

 for i := 0 to High(TBallsImageSet) do
  for bf := LowNonEmptyBF to HighNonEmptyBF do
   FreeAndNil(NonEmptyBFImages[i, bf]);
end;

initialization
 ApplicationProperties.OnGLContextOpen.Add(@ContextOpen);
 ApplicationProperties.OnGLContextClose.Add(@ContextClose);
finalization
end.
