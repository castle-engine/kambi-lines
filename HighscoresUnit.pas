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

unit HighscoresUnit;

interface

uses SysUtils, KambiUtils, Classes;

{$define read_interface}

const MaxPlayerNameLength = 10;
type
  THighscore = record
    PlayerName: string[MaxPlayerNameLength];
    Score: Integer;
  end;
  PHighscore = ^THighscore;

  TDynArrayItem_1 = THighscore;
  PDynArrayItem_1 = PHighscore;
  {$define DYNARRAY_1_IS_STRUCT}
  {$I DynArray_1.inc}
  TDynHighscoresArray = TDynarray_1;

const
  MaxHighscoresCount = 10; { musi byc > 0 }

var
  { Highscores object is readonly from outside of this module.
    It is saved/loaded from some file in initialization/finalization of this unit.
    It always has Count >= 1 so there is always a King.
    KingScore = Highscores.Pointers[0]. Wieksze indeksy
      w tablicy oznaczaja coraz gorszych graczy, az ostatnie miejsce to
      najgorszy gracz ktory jeszcze zmiescil sie w tablicy Highscores
      (ale gracze o ilosci punktow 0 nie trafiaja tu nigdy, nawet jesli sa
      wolne sloty w Highscores).
    Zmiescil sie, bo tablica Highscores ma zawsze Count <= MaxHighscoresCount.
      Gdy dodajesz do niej nowych graczy gracze z konca tablicy (tzn. najgorsi)
      sa usuwani. }
  Highscores: TDynHighscoresArray;

{ wywolaj to po kazdej zakonczonej przez gracza grze; sprawdza czy gracz
  kwalifikuje sie do highscores i jesli tak - pyta sie gracza o imie
  i dopisuje go do highscores. }
procedure CheckAndMaybeAddToHighscore(AScore: Integer);

{ = Highscores.Pointers[0]. Zawsze KingScore.Score > 0 }
function KingScore: PHighscore;

{ rysuje highscores. Pamietaj ze to wypelnia tylko pewna czesc na srodku
  ekranu wiec zawsze przed wywolaniem tej procedury bedziesz chcial narysowac
  najpierw jakies tlo. }
procedure DrawHighscores;

{$undef read_interface}

implementation

uses VectorMath, LinesWindow, GLWindow, GLWinMessages, OpenGLh,
  KambiGLUtils, Images, GLWinInputs, KambiStringUtils, KambiFilesUtils;

{$define read_implementation}
{$I DynArray_1.inc}

function CheckNewScore(AScore: Integer): Integer;
{ CheckNewScore sprawdza czy AScore jest na tyle wysoki ze gracz powinien
    byc wstawiony w ktores miejsce na liscie Highscores.
  CheckNewScore zwraca liczbe z przedzialu
    0..min(Highscores.Count, MaxHighscoresCount-1) jesli gracz powinien byc
    wstawiony na odpowiednia pozycje w Highscores. Zwracam uwage ze
    zgodnie z powysza definicja CheckNewScore MOZE zwrocic Highscores.Count
    a wiec moze nakazac zeby nowy Score zostal dopisany na koncu listy
    Highscores ale TYLKO jesli Highscores.Count < MaxHighscoresCount
    a wiec tylko jesli na liscie jest jeszcze miejsce na nowego gracza na
    koncu.
  CheckNewScore zwraca -1 jesli gracz nie kwalifikuje sie aby go wstawic
    na liste Highscores.
  Pamietaj ze CheckNewScore nie wykonuje faktycznego wstawienia gracza
    na liste Highscores (i nie moze - nie zna przeciez PlayerName,
    a my nie mozemy go podac jako parametr do CheckNewScore bo przeciez
    graczy ktorzy sie nie zakwalifikuja do Highscores nie chcemy nawet
    pytac o imie).
  Jezeli checkNewScores odpowie cos <>-1 to powinienes zapytac gracza
    o imie i wywolac AddToHighscores(<pobrane-ime-gracza>, <wynik-CheckNewScore>) }
var i: Integer;
begin
 if AScore = 0 then Exit(-1);

 for i := 0 to Highscores.Count-1 do
  if AScore > Highscores.Items[i].Score then Exit(i);
 {nie wygral z zadnym elementem sposrod Highscores ? OK, wiec mozemy go
  jszcze dopisac na koncu o ile mamy miejsce}
 if Highscores.Count < MaxHighscoresCount then
  result := Highscores.Count else
  result := -1;
end;

procedure AddToHighscores(Position: integer; const APlayerName: string; AScore: Integer);
{ AddToHighscores wstawia nowy Highscore o podanych parametrach na miejsce
    Position. Elementy od Position do Highscores.High sa przesuwane o jeden
    indeks dalej (ostatni element jest ew. kasowany zeby zawsze Highscores
    mialo zawsze Count <= MaxHighscoresCount.).
  AddToHighscores nie sprawdza w zaden sposob czy taka wysokosc AScore
    jest dobra na tej pozycji w Highscores - zawsze powinienes
    podawac jako Position wynik CheckNewScore wywolanego przed chwila. }
var H: THighscore;
begin
 H.PlayerName := APlayerName;
 H.Score := AScore;
 Highscores.Insert(Position, H);
 if Highscores.Count > MaxHighscoresCount then Highscores.Delete(Highscores.High, 1);
end;

function KingScore: PHighscore;
begin result := Highscores.Pointers[0] end;

{ displaying functions ------------------------------------------------------- }

var dlImgHighscr: TGLuint;

const
  HighscrX0 = (640-235) div 2 + 3;
  HighscrY0 = (350-167) div 2 + 7;
  HighscrScoreX = 415;
  HighscrNameX = 248;
  HighscrRowHeight = 120 div MaxHighscoresCount;

function HighscrNameY(Pos: Integer): Integer;
begin
 result:=(MaxHighscoresCount-1-Pos)*HighscrRowHeight + HighscrY0 + 16;
end;

procedure DrawHighscores;

  procedure Print(const s: string; x, y: Integer);
  begin
   glRasterPos2i(x-LinesFont.TextWidth(s), y);
   LinesFont.PrintAndMove(s);
  end;

var i, RowY: Integer;
begin
 glRasterPos2i(HighscrX0, HighscrY0);
 glCallList(dlImgHighscr);

 glColorv(Vector3Byte(0, 168, 0));

 for i := 0 to MaxHighscoresCount-1 do
 begin
  RowY := HighscrNameY(i);
  Print(IntToStr(i+1)+'. ', HighscrNameX, RowY);
  if i < Highscores.Count then
  begin
   LinesFont.Print(Highscores.Items[i].PlayerName);
   Print(IntToStr(Highscores.Items[i].Score), HighscrScoreX, RowY);
  end;
 end;
end;

procedure CheckAndMaybeAddToHighscore(AScore: Integer);
var Pos: Integer;
begin
 Pos := CheckNewScore(AScore);
 if Pos >= 0 then
 begin
  AddToHighscores(Pos, '', AScore);
  DrawHighscores;
  Highscores.Items[Pos].PlayerName:=
    Input(glw, GL_BACK, false, LinesFont, ScreenX0, ScreenY0,
      HighscrNameX, HighscrNameY(Pos), '', 0, MaxPlayerNameLength, AllChars);
 end;
end;

{ Load/Save Highscores --------------------------------------------------- }

function HighscoresFilename: string;
begin
 result := UserConfigFile('.hsc');
end;

procedure LoadHighscores;

  const
    { uzywamy StandardKing'a gdy nie ma pliku z highscores (bo np. gra zostala
      uruchomiona pierwszy raz). Poniewaz zawsze chcemy miec KingScore wiec
      musimy wtedy dodac tego StandardKing. }
    StandardKing: THighscore = (PlayerName:'Handicap'; Score:100);

var S: TFileStream;
    hc: Integer;
begin
 Highscores.Count := 0;
 try
  S := TFileStream.Create(HighscoresFilename, fmOpenRead);
 except Highscores.AppendItem(StandardKing); Exit end;
 try
  S.ReadBuffer(hc, SizeOf(hc));
  Highscores.Count := hc;
  S.ReadBuffer(Highscores.Items[0], SizeOf(THighscore)*hc);
 finally S.Free end;

 { o ile nikt nie grzebal brzydko w highscr.scr also w tym programie
   to te zalozenia powinny byc zawsze prawdziwe }
 Check(Highscores.Count > 0, 'Highscores.Count must be > 0');
 Check(KingScore^.Score > 0, 'KingScore.Count must be > 0');
end;

procedure SaveHighscores;
var S: TFileStream;
    hc: Integer;
begin
 S := TFileStream.Create(HighscoresFilename, fmCreate);
 try
  hc := Highscores.Count;
  S.WriteBuffer(hc, SizeOf(hc));
  S.WriteBuffer(Highscores.Items[0], SizeOf(THighscore)*hc);
 finally S.Free end;
end;

{ Init/Close GL --------------------------------------------------------------- }

procedure InitGL(glwin: TGLWindow);
begin
 dlImgHighscr := LoadImageToDispList(ImagesPath+'highscr.png', [TRGBImage], [], 0, 0);
end;

{ unit init/fini ------------------------------------------------------------- }

initialization
 Highscores := TDynHighscoresArray.Create;
 LoadHighscores;
 glw.OnInitList.AppendItem(@InitGL);
finalization
 SaveHighscores;
 FreeAndNil(Highscores);
end.
