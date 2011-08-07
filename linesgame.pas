{
  Copyright 2003-2011 Michalis Kamburelis.

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

{ kilka ogolnych rzeczy zwiazanych z mechanika gry, zbyt malych zeby
  tworzyc dla nich osobne moduly, zbyt niezaleznych rzeczy dolaczac
  je do innych modulow.

  Zalezy od LinesBoard. NIE zalezy od w ogole od OpenGLa a wiec i od
  LinesWindow, DrawingGame, LinesMove i GetPlayerActionUnit. }

unit LinesGame;

interface

uses LinesBoard, VectorMath, KambiClassUtils;

const
  Version = '1.1.5';
  DisplayProgramName = 'kambi_lines';

{ NextColors ---------------------------------------------------------- }

const
  NextColorsCount = 3;
var
  NextColors: array[0..NextColorsCount-1]of TNonEmptyBF;

{ PlayerScore -------------------------------------------------------- }

var
  PlayerScore: Integer;
  BonusScoreMultiplier: Integer;

{ preferencje gracza ----------------------------------------------------------
  Beda sejwowane / ladowane z pliku ini, domyslne wartosci tych zmiennych
  jakie im nadaje ponizej beda domyslnymi wartosciami przy odczytywaniu
  tych zmiennych z pliku ini. }

var
  ShowNextColors: boolean = true;
  { jesli not AllowSpecialBalls to do NextColors (i do poczatkowych
    StartGamePicesCount) beda mogly byc wylosowane tylko normalne
    1-kolorowe kulki, czyli wszystko bedzie dzialac tak jak w oryginalnych
    lines. Wpp. wszystie rodzaje kulek TNonEmptyBF beda mogly sie pojawic. }
  AllowSpecialBalls: boolean = true;

type
  TBallsImageSet = 0..1;
var
  BallsImageSet: TBallsImageSet = 1;

{ funkcje ------------------------------------------------------------------- }

{ jezeli DoBoard to cala Board := bfEmpty,
  jezeli DoNextColors to NextColors := RandomBall (a wiec uzywa AllowSpecialBalls),
  jezeli DoScore to PlayerScore := 0, BonusScoreMultiplier := 1 }
procedure ClearGame(DoBoard, DoNextColors, DoScore: boolean);

{ wykonaj wszystko co nalezy wykonac pomiedzy jednym a drugim ruchem gracza;
  a wiec:
  - sprawdz czy na planszy ulozyly sie jakies linie z kulek,
    jesli tak to je skasuj i dodaj za nie punkty dla gracza i zakoncz
  - jesli nie to dodaj kulki w kolorach NextColors do planszy,
    kasujac od razu linie jakie sie przypadkiem utworza (ale za te linie
      gracz nie dostaje punktow)
    (jesli nie bedzie mozna dodac kulek z NextColors to wyjdzie z false i
      gra powinna zostac zakonczona)
    i wylosuj nowe NextColors.
  - wyjdz z true jesli na planszy jest jeszcze chociaz 1 wolne pole.
    W rezultacie, jezeli wyjdziemy stad z true to na pewno gracz moze
    wykonac jeszcze ruch. }
function EndGameTurn: boolean;

{ znajdz linie na planszy jakie pasuja do siebie, skasuj je i zwroc ilosc
  kulek w pasujacych liniach (nie zwieksza automatycznie PlayerScore, musisz
  sam zrobic
    PlayerScore += DeleteMatchingLines * 2 * PointsMultiplier
  jesli tego chcesz) }
function DeleteMatchingLines: Integer;

{ wylosuj pole na Board ktore ma bfEmpty (zwroc false jesli nie ma takiego pola).
  Zrob DeleteMatchingLines (ignorujac wynik, tzn. gracz nie dostaje za to
  punktow) i zwroc true. }
function PutBallOnRandomEmptyBoardPos(BF: TNonEMptyBF): boolean;

{ Jesli AllowSpecialBalls to zwroci losowe TNonEmptyBF.
  Wpp. zwroci losowe TSingleColourBF.
  W obu przypadkach losowe nie oznacza rozkladu rownomiernego - patrz tutejsza
  implementacja po szczegoly. }
function RandomBall: TNonEmptyBF;

implementation

uses SysUtils, KambiUtils, KambiFilesUtils, KambiXMLConfig;

procedure ClearGame(DoBoard, DoNextColors, DoScore: boolean);
var i, j: Integer;
begin
 if DoBoard then
 begin
  for i := 0 to BoardWidth-1 do
   for j := 0 to BoardHeight-1 do
    Board[i, j] := bfEmpty;
 end;
 if DoNextColors then
  for i := 0 to NextColorsCount-1 do NextColors[i] := RandomBall;
 if DoScore then
 begin
  PlayerScore := 0;
  BonusScoreMultiplier := 1;
 end;
end;

{ ExistsEmptyBoardPos i PutBallOnRandomEmptyBoardPos can be enormously
  optimised by creating TBoard as class and managing there a list of empty
  board fields.
  (CreateEmptyPositions would not have to be computed each time).
  But everything works smooth for now, so I guess it's not important to
  do this optimisation. (well, in one EndGameTurn you call
  CreateEmptyPositions four times and, since the board is only 9x9 = 81 pieces,
  this does not take really much time, to be honest).
  So I am not going to do this optimisations unless I'll see some reason. }

function CreateEmptyPositions: TVector2IntegerList;
var i, j: Integer;
begin
 result := TVector2IntegerList.Create;
 try
  { konstruuj zawartosc EmptyPositions }
  result.Capacity := BoardWidth*BoardHeight;
   for i := 0 to BoardWidth-1 do
    for j := 0 to BoardHeight-1 do
     if Board[i, j] = bfEmpty then
      result.Add(Vector2Integer(i, j));
 except result.Free; raise end;
end;

function ExistsEmptyBoardPos: boolean;
{ czy na Board istnieje chociaz jedno pole bfEmpty ? Jesli true to jest
  gwarantowane ze PutBallOnRandomEmptyBoardPos zwroci true, wpp.
  PutBallOnRandomEmptyBoardPos zwroci na pewno false.
  W tym momencie wywolywanie ExistsEmptyBoardPos tylko po to zeby
  sie przekonac co zwroci PutBallOnRandomEmptyBoardPos jest bardzo
  nieoptymalne (obie funkcje konstruuja sobie EmptyPositions). }
var EmptyPositions: TVector2IntegerList;
begin
 EmptyPositions := CreateEmptyPositions;
 try
  result := EmptyPositions.Count <> 0;
 finally EmptyPositions.Free end;
end;

function PutBallOnRandomEmptyBoardPos(BF: TNonEmptyBF): boolean;
var Pos: TVector2Integer;
    EmptyPositions: TVector2IntegerList;
begin
 EmptyPositions := CreateEmptyPositions;
 try
  if EmptyPositions.Count = 0 then Exit(false);
  Pos := EmptyPositions.Items[Random(EmptyPositions.Count)];
  result := true;
 finally EmptyPositions.Free end;

 Board[Pos[0], Pos[1]] := BF;
 DeleteMatchingLines;
end;

function EndGameTurn: boolean;
var MatchingPoints, i: Integer;
begin
 MatchingPoints := DeleteMatchingLines;
 if MatchingPoints <> 0 then
 begin
  PlayerScore += MatchingPoints * 2 * BonusScoreMultiplier;
  Inc(BonusScoreMultiplier);
 end else
 begin
  BonusScoreMultiplier := 1;

  { dodaj kulki z NextColors }
  for i := 0 to NextColorsCount-1 do
  begin
   if not PutBallOnRandomEmptyBoardPos(NextColors[i]) then
    Exit(false);
  end;

  { losuj nowe NextColors }
  ClearGame(false, true, false);
 end;
 result := ExistsEmptyBoardPos;
end;

function DeleteMatchingLines: Integer;
const
  MatchingColours: array[TBoardField]of TSingleColourBFs =
  ([], [bfBrown], [bfYellow], [bfGreen], [bfWhite], [bfViolet], [bfRed], [bfBlue],
   [bfBlue, bfYellow], [bfRed, bfWhite],
   [LowSingleColourBF..HighSingleColourBF]);

  function SeekMatchingColoursDir(x0, y0, dx, dy: Integer): Integer;
  { zwroc ile jest pol pasujacych do rodzaju Board[x0, y0] idac od pola x0, y0
    w strone dx, dy (dx, dy powinny byc liczbami z zakresu -1, 0, -1).
    W wynik nie wlicza samego "wzorcowego" pola x0, y0.
    Board[x0, y0] musi byc in AllSingleColourBFs. }
  var ColorToMatch: TSingleColourBF;
  begin
   result := 0;
   ColorToMatch := Board[x0, y0];
   repeat
    x0 += dx;
    y0 += dy;
    if Between(x0, 0, BoardWidth-1) and
       Between(y0, 0, BoardHeight-1) and
       (ColorToMatch in MatchingColours[Board[x0, y0]]) then
     Inc(result) else
     break;
   until false;
  end;

var LinesToDelete: TVector2IntegerList;
const LineLengthToMatch = 5;

  procedure TryDeleteBall(const Pos: TVector2Integer);
  var i: Integer;
  begin
   i := LinesToDelete.IndexOf(Pos);
   if i = -1 then LinesToDelete.Add(Pos);
  end;

  procedure TryMatchLine(x0, y0, dx, dy: Integer);
  { Wywoluj tylko dla Board[x0, y0] in AllSingleColourBFs }
  var Dir1Match, Dir2Match, i: Integer;
  begin
   { nie mozemy ponizej zaniechac sprawdzania Dir2Match jesli Dir2Match
     juz jest >= LineLengthToMatch bo musimy wychwycic wszystkie kulki
     spoza AllSingleColourBFs do skasowania. }
   Dir1Match := SeekMatchingColoursDir(x0, y0, dx, dy);
   Dir2Match := SeekMatchingColoursDir(x0, y0, -dx, -dy);

   if Dir1Match + Dir2Match + 1 >= LineLengthToMatch then
   begin
    for i := 1 to Dir1Match do TryDeleteBall(Vector2Integer(x0 + dx*i, y0 + dy*i));
    for i := 1 to Dir2Match do TryDeleteBall(Vector2Integer(x0 - dx*i, y0 - dy*i));
    TryDeleteBall(Vector2Integer(x0, y0));
   end;
  end;

var i, j: Integer;
begin
 result := 0;

 LinesToDelete := TVector2IntegerList.Create;
 try
  { LineLengthToMath+1 "na oko" wydaje sie byc tu dobrym przyblizeniem,
    najczesciej jesli znikna jakies kulki to bedzie ich dokladnie
    LineLengthToMatch, rzadko +1, prawie nigdy wiecej. }
  LinesToDelete.Capacity := LineLengthToMatch + 1;

  for i := 0 to BoardWidth-1 do
   for j := 0 to BoardHeight-1 do
    if Board[i, j] in AllSingleColourBFs then
    begin
     { Musimy robic TryMatchLine dla wszystkich czterech mozliwych linii
       (nie mozemy konczyc po znalezieniu pierwszej linii dzieki ktorej
       kulka i, j kwalifikuje sie do skasowania). Musimy to takze robic nawet
       jesli kulka (i, j) JUZ byla wsrod LinesToDelete.
       Wszystko to zeby na pewno wychwycic wszystkie kulki spoza
       AllSingleColourBFs do skasowania. }
     TryMatchLine(i, j, -1, -1);
     TryMatchLine(i, j, 1, -1);
     TryMatchLine(i, j, 0, 1);
     TryMatchLine(i, j, 1, 0);
    end;

  result := LinesToDelete.Count;

  { TODO: jakas animacyjka na znikanie kulek bedzie tu zrobiona pozniej }
  for i := 0 to LinesToDelete.Count-1 do
   Board[LinesToDelete.L[i][0], LinesToDelete.L[i][1]] := bfEmpty;

 finally LinesToDelete.Free end;
end;

function RandomBall: TNonEmptyBF;
const
  OrdLowNonEmptyBF = Ord(LowNonEmptyBF);
  OrdHighNonEmptyBF = Ord(HighNonEmptyBF);
  NonEmptyBFCount = OrdHighNonEmptyBF - OrdLowNonEmptyBF + 1;

  OrdLowSingleColourBF = Ord(LowSingleColourBF);
  OrdHighSingleColourBF = Ord(HighSingleColourBF);
  SingleColourBFCount = OrdHighSingleColourBF - OrdLowSingleColourBF + 1;

  OrdLowSpecialBF = Ord(LowSpecialBF);
  OrdHighSpecialBF = Ord(HighSpecialBF);
  SpecialBFCount = OrdHighSpecialBF - OrdLowSpecialBF + 1;

  { jezeli AllowSpecialBalls to rozklad prawdop bedzie taki
    (wyliczenia liczbowe zakladaja konkretne wartosci wszystkich stalych) :
    All = SpecialBFCount + SingleColourBFCount * RatioSingleColour =
      3 + 7 * 3 = 24
    SpecialBFCount / All = 3 / 24 = 1/8 = szansa na kulke non-single-colour,
      rozkladana juz dalej rownomiernie na poszczegolne kulki
    SingleColourBFCount * RatioSingleColour / All = 7*3 / 24 = 7/8 =
      szansa na kulke single-colour, rozkladana juz dalej rownomiernie.

    Dla aktualnych danych mamy wiec sytuacje ze 7/8 jest rozkladane na 7 kulek
      single-colour i pozostale 1/8 to 3 kulki special. Tak jakby 3 kulki
      special byly 1 kolorem. }
  RatioSingleColour = 3;

var i: Integer;
begin
 if AllowSpecialBalls then
 begin
  i := Random(SpecialBFCount + SingleColourBFCount * RatioSingleColour);
  if i < SpecialBFCount then
   result := TNonEmptyBF(OrdLowSpecialBF + i) else
   result := TNonEmptyBF(OrdLowSingleColourBF + (i-SpecialBFCount) div RatioSingleColour);
 end else
  result := TNonEmptyBF(OrdLowSingleColourBF + Random(SingleColourBFCount));
end;

{ Loading / saving config ---------------------------------------------------- }

var Conf: TKamXMLConfig;

procedure LoadConfig;
begin
  Conf := TKamXMLConfig.Create(nil);
  Conf.FileName := UserConfigFile('.conf');
  ShowNextColors := Conf.GetValue('prefs/ShowNextColors', ShowNextColors);
  AllowSpecialBalls := Conf.GetValue('prefs/AllowSpecialBalls', AllowSpecialBalls);
  BallsImageSet := Conf.GetValue('prefs/BallsImageSet', BallsImageSet);
end;

procedure SaveConfig;
begin
  if Assigned(Conf) then
  begin
    Conf.SetValue('prefs/ShowNextColors', ShowNextColors);
    Conf.SetValue('prefs/AllowSpecialBalls', AllowSpecialBalls);
    Conf.SetValue('prefs/BallsImageSet', BallsImageSet);
    Conf.Flush;
    FreeAndNil(Conf);
  end;
end;

{ unit init/fini -------------------------------------------------------------- }

initialization
 LoadConfig;
finalization
 SaveConfig;
end.
