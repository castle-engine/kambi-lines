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

unit LinesBoard;

{ NIE zalezy od OpenGLa (a wiec i od LinesWindow, DrawingGame, GetPlayerMove,
    LinesMove i innych) ani od LinesGame. }

interface

uses SysUtils, KambiUtils, VectorMath;

{$define read_interface}

{ typy --------------------------------------------------------------------- }

type
  TDynArrayItem_1 = TVector2Integer;
  PDynArrayItem_1 = PVector2Integer;
  {$define DYNARRAY_1_IS_STRUCT}
  {$define DYNARRAY_1_USE_EQUALITY_COMPAREMEM}
  {$I DynArray_1.inc}
  TDynVector2IntegerArray = TDynArray_1;
  
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
  Way: TDynVector2IntegerArray): boolean;

{ CWayOnTheBoard to wersja Cached funkcji WayOfTheBoard. Przechowuje swoje
  wyniki i jesli drugi raz zapytasz sie jej o takie same X1, Y1, X2, Y2
  to zwroci odpowiedz blyskawicznie, bez wzgledu na to jak dlugo dzialaloby
  WayOnTheBoard. Zwrocona droga bedzie w CWayResultWay (bo kopiowanie jej
  kazdorazowe do dostarczanej przez ciebie tablicy Way: TDynVector2IntegerArray
  powodowaloby strate czasu ktora niweczylaby skutki cache'owania). 
  
  Za kazdym razem kiedy dokonasz jakies zmiany na Board i chcesz uzyc tej
  funkcji musisz najpierw wywolac CWayClearCache. 
  
  Zmienna CWayResultWay jest tylko do odczytu. }
var CWayResultWay: TDynVector2IntegerArray;
function CWayOnTheBoard(const A, B: TVector2Integer): boolean;
procedure CWayClearCache;

{$undef read_interface}  

implementation

{$define read_implementation}
{$I DynArray_1.inc}

{ WayOnTheBoard* ------------------------------------------------------------ }

function WayOnTheBoard(A: TVector2Integer; const B: TVector2Integer;
  Way: TDynVector2IntegerArray): boolean;
  
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
      DirToDXY: array[TDir]of TVector2Integer= ((0, 1), (-1, 0), (0, -1), (1, 0));

    function TryNeighbour(x, y: Integer): boolean; overload;
    begin
     result:=(x >= 0) and (y >= 0) and (x < BoardWidth) and (y < BoardHeight) and
       (Board[x, y] = bfEmpty) and FindWay(x, y);
     if result and (Way <> nil) then Way.Add(Vector2Integer(x, y));
    end;
    
    function TryNeighbour(Dir: TDir): boolean; overload;
    begin
     result := TryNeighbour(x+DirToDXY[Dir, 0], y+DirToDXY[Dir, 1]);
    end;

  var Pref: array[1..4]of TDir;
      VertPrefDir, HorizPrefDir: TDir;
  begin
   if Visited[x, y] then
    result := false else
   begin
    Visited[x, y] := true;
    if (x = B[0]) and (y = B[1]) then
    begin
     result := true;
     if Way <> nil then Way.Length := 0;
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
     if x <= B[0] then HorizPrefDir := dirRight else HorizPrefDir := dirLeft;
     if y <= B[1] then VertPrefDir := dirUp     else VertPrefDir := dirDown;
     if Abs(x-B[0]) > Abs(y-B[1]) then
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
 result := FindWay(A[0], A[1]);
 if result and (Way <> nil) then Way.Reverse;
end;

var
  CWayA: TVector2Integer = (-1, -1);
  CWayB: TVector2Integer = (-1, -1);
  CWayResult: boolean;

function CWayOnTheBoard(const A, B: TVector2Integer): boolean;
begin
 if (A[0] = CWayA[0]) and (A[1] = CWayA[1]) and
    (B[0] = CWayB[0]) and (B[1] = CWayB[1]) then
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
 CWayA[0] := -1;
 CWayA[1] := -1;
 CWayB[0] := -1;
 CWayB[1] := -1;
end;

initialization
 CWayResultWay := TDynVector2IntegerArray.Create;
finalization 
 FreeAndNil(CWayResultWay);
end.
