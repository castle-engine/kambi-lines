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

{ Storing and searching path on board. }
unit LinesBoard;

{ NIE zalezy od OpenGLa (a wiec i od LinesWindow, DrawingGame, GetPlayerMove,
    LinesMove i innych) ani od LinesGame. }

interface

uses SysUtils,
  CastleUtils, CastleVectors;

{ typy --------------------------------------------------------------------- }

const
  { BoardWidth/Height musza byc <= High(Byte). Ponadto w rzeczywistosci powinny
    byc DUZO mniejsze zeby dalo sie je sensownie wyswietlac na ekranie.  }
  BoardWidth = 9;
  BoardHeight = 9;

type
  TBoardField = (bfEmpty,
    bfBrown, bfYellow, bfGreen, bfWhite, bfViolet, bfRed, bfBlue,
    bfBlueYellow, bfRedWhite,
    bfJoker
  );
  { TNonEmptyBF to ZAWSZE bedzie typ TBoardField poza bfEmpty,
    tzn. nie moze byc elementow w TBoardField ktorych nie ma w TNonEmptyBF
    innych niz bfEmpty. }
  TNonEmptyBF = Succ(bfEmpty) .. High(TBoardField);
  TSingleColourBF = bfBrown .. bfBlue;
  TDoubleColourBF = bfBlueYellow .. bfRedWhite;
  TSpecialBF =  bfBlueYellow .. High(TBoardField);

  TSingleColourBFs = set of TSingleColourBF;

const
  { consts needed due to bug in FPC 1.0.x }
  LowNonEmptyBF = Low(TNonEmptyBF);
  HighNonEmptyBF = High(TNonEmptyBF);
  LowSingleColourBF = Low(TSingleColourBF);
  HighSingleColourBF = High(TSingleColourBF);
  LowSpecialBF = Low(TSpecialBF);
  HighSpecialBF = High(TSpecialBF);

  AllSingleColourBFs = [Low(TSingleColourBF) .. High(TSingleColourBF)];
var
  Board: array[0..BoardWidth-1, 0..BoardHeight-1]of TBoardField;

type
  TVector2IntegerList = specialize TStructList<TVector2Integer>;

{ funkcje ----------------------------------------------------------------- }

{ sprawdza czy istnieje droga z A do B na planszy po wolnych polach.
  Jesli tak to zwraca true, wpp. zwraca false. Jesli zwraca true i
  Way <> nil to odpowiednia droge zapisze do Way w postaci kolejnych
  wspolrzednych kolejnych pol na drodze zaczynajac od A (ale samo
  A nie bedzie w Way) i konczac w B (B bedzie w Way).
  Nie sprawdza czy A i B sa puste czy nie.

  Nie podawaj jako A i B tych samych pol - nie jest zdefiniowane
  co wtedy odpowie ta funkcja i co bedzie w Way. (po prostu dlatego
  ze jeszcze nie widze sensownosci w zadnej definicji, w obecnej chwili
  wiem ze zawsze WayOnTheBoard bedzie uzywane z roznymi polami). }
function WayOnTheBoard(A: TVector2Integer; const B: TVector2Integer;
  Way: TVector2IntegerList): boolean;

{ CWayOnTheBoard to wersja Cached funkcji WayOfTheBoard. Przechowuje swoje
  wyniki i jesli drugi raz zapytasz sie jej o takie same X1, Y1, X2, Y2
  to zwroci odpowiedz blyskawicznie, bez wzgledu na to jak dlugo dzialaloby
  WayOnTheBoard. Zwrocona droga bedzie w CWayResultWay (bo kopiowanie jej
  kazdorazowe do dostarczanej przez ciebie tablicy Way: TVector2IntegerList
  powodowaloby strate czasu ktora niweczylaby skutki cache'owania).

  Za kazdym razem kiedy dokonasz jakies zmiany na Board i chcesz uzyc tej
  funkcji musisz najpierw wywolac CWayClearCache.

  Zmienna CWayResultWay jest tylko do odczytu. }
var CWayResultWay: TVector2IntegerList;
function CWayOnTheBoard(const A, B: TVector2Integer): boolean;
procedure CWayClearCache;

implementation

{ WayOnTheBoard* ------------------------------------------------------------ }

function WayOnTheBoard(A: TVector2Integer; const B: TVector2Integer;
  Way: TVector2IntegerList): boolean;

var Visited: array[0..BoardWidth-1, 0..BoardHeight-1]of boolean;

  function FindWay(x, y: Integer): boolean;
  { znajdz droge do B z x, y. Podane x, y musi juz byc w zakresie pol planszy,
    tzn. x = 0..BoardWidth-1 y = analogicznie.
    Wszystkie pola po drodze musza byc bfEmpty, poza x, y.
    Jesli znajdziesz - zwroc true i zapisz do Way droge w
    odwrotnej kolejnosci (tzn. pierwszy punkt to B, potem punkt sasiedni do B
    itd. - az ostatni punkt w Way to punkt sasiedni do x, y).
    Jesli nie znajdziesz - zwroc false (i oczywiscie nie dotykaj Way !)
  }
    type
      { zwracam uwage ze typ jest ulozony tak zeby cykliczne dodawanie/odejmowanie
        1-ki zmienialo kierunek o 90 stopni. }
      TDir = (dirUp, dirLeft, dirDown, dirRight);
    const
      DirToDXY: array [TDir] of TVector2Integer= (
        (X: 0; Y: 1),
        (X: -1; Y: 0),
        (X: 0; Y: -1),
        (X: 1; Y: 0)
      );

    function TryNeighbour(x, y: Integer): boolean; overload;
    begin
     result:=(x >= 0) and (y >= 0) and (x < BoardWidth) and (y < BoardHeight) and
       (Board[x, y] = bfEmpty) and FindWay(x, y);
     if result and (Way <> nil) then Way.Add(Vector2Integer(x, y));
    end;

    function TryNeighbour(Dir: TDir): boolean; overload;
    begin
      Result := TryNeighbour(
        x + DirToDXY[Dir].X,
        y + DirToDXY[Dir].Y
      );
    end;

  var Pref: array[1..4]of TDir;
      VertPrefDir, HorizPrefDir: TDir;
  begin
   if Visited[x, y] then
    result := false else
   begin
    Visited[x, y] := true;
    if (x = B.X) and (y = B.Y) then
    begin
     result := true;
     if Way <> nil then Way.Count := 0;
    end else
    begin
     { gdyby nie zalezalo nam na mozliwie krotkiej drodze wystarczyloby tutaj
       result := TryNeighbour(x, y+1) or TryNeighbour(x, y-1) or
              TryNeighbour(x+1, y) or TryNeighbour(x-1, y);}

     { chcemy ustalic Pref - liste kierunkow w kolejnosci najbardziej
       obiecujacych. Wybieramy najprostsza strategie : idz w kierunku
       najblizszym do B. Wybieramy najpierw dwa kierunki,
       poziomy i pionowy w kierunku B, to sa pierwsze dwa preferowane
       kierunki. Ktory bardziej ? Ten wzdluz ktorego roznica wspolrzednych
       jest wieksza. Trzeci Pref to odwrocony drugi kierunke
       (w ten sposob drugi i trzeci kierunek sa najblizszymi kierunkami
       do pierwszego). }
     if x <= B.X then HorizPrefDir := dirRight else HorizPrefDir := dirLeft;
     if y <= B.Y then VertPrefDir := dirUp     else VertPrefDir := dirDown;
     if Abs(x-B.X) > Abs(y-B.Y) then
     begin
      Pref[1] := HorizPrefDir;
      Pref[2] := VertPrefDir;
     end else
     begin
      Pref[1] := VertPrefDir;
      Pref[2] := HorizPrefDir;
     end;
     Pref[3] := TDir(ChangeIntCycle(Ord(Pref[2]),+2, 3));
     Pref[4] := TDir(ChangeIntCycle(Ord(Pref[1]),+2, 3));

     result := TryNeighbour(Pref[1]) or
             TryNeighbour(Pref[2]) or
             TryNeighbour(Pref[3]) or
             TryNeighbour(Pref[4]);
    end;
   end;
  end;

begin
 FillChar(Visited, SizeOf(Visited), 0);
 result := FindWay(A.X, A.Y);
 if result and (Way <> nil) then Way.Reverse;
end;

var
  CWayA: TVector2Integer = (X: -1; Y: -1);
  CWayB: TVector2Integer = (X: -1; Y: -1);
  CWayResult: boolean;

function CWayOnTheBoard(const A, B: TVector2Integer): boolean;
begin
 if (A.X = CWayA.X) and (A.Y = CWayA.Y) and
    (B.X = CWayB.X) and (B.Y = CWayB.Y) then
  result := CWayResult else
 begin
  CWayResult := WayOnTheBoard(A, B, CWayResultWay);
  CWayA := A;
  CWayB := B;
  result := CWayResult;
 end;
end;

procedure CWayClearCache;
begin
 CWayA.X := -1;
 CWayA.Y := -1;
 CWayB.X := -1;
 CWayB.Y := -1;
end;

initialization
 CWayResultWay := TVector2IntegerList.Create;
finalization
 FreeAndNil(CWayResultWay);
end.
