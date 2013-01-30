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

program kambi_lines;

{ Zaczete gdzies w czerwcu 2003, ale praktycznie wzialem sie do roboty
    dopiero 27 lipca.
  28 lipca mam juz gotowe wszystko to co jest
    w oryginalnych kulkach poza sprawdzaniem czy trafil do Highscores
    i load/save highscores do pliku.
  29 lipca juz zrobione wszystko z Highscores i zrobiony tryb
    fullscreen 640x480. Dorobione tez male dodatki. Jeszcze tylko
    zrobic Help na F1 i bedziemy mieli absolutnie wszystko co w
    oryginalnych kulkach - ale help troche poczeka, bo chce dodac
    tam info o jokerach, dubletach i bonusach za zbieranie w kolejnych
    turach, czego jeszcze nie zaimplementowalem.
  30/31 lipca zrobione jokery, kulki dwu-kolorowe, sejwowanie ustawien
    do pliku ini, help screen z objasnieniem wszystkich rzeczy (w oryginalnych
    lines.exe help to byly chyba 3 zdania, u mnie wyszly 3 ekrany),
    i zrobiony moj wlasny ekran tytulowy (generowany rayhunterem classic !).
    Zrobiona tez obsluga przyciskow na dole ekranu myszka.
    Tym samym uznaje ze w zasadzie zrobilem wszystko co chcialem zrobic
    w tym programie i ten program UWAZAM ZA SKONCZONY.
  1 lipca kulki wrzucone na www/camelot z minimalna dokumentacja:
    jak zainstalowac pod linuxem i windows i o parametrze --fullscreen.
}

{ TODO:
  interfejs (i cala reszta) aby user mogl sobie ustalic
    StartGamePiecesCount,
    NextColorsCount,
    LineLengthToMatch,
    BoardWidth/BoardHeight

  LinesFont font could be larger. But then help text would be larger
    then 3 screens. Free font "Arial CE / Latin 2" is quite awful.
}

{$apptype GUI}

uses SysUtils, CastleWindow, LinesWindow, CastleUtils, HighscoresUnit,
  GetPlayerActionUnit, CastleMessages, CastleGLUtils, LinesBoard,
  CastleVectors, LinesMove, LinesGame, CastleInputAny,
  CastleParameters, CastleClassUtils;

{ params ------------------------------------------------------------ }

const
  Options: array[0..1]of TOption = (
    (Short: 'h'; Long: 'help'; Argument: oaNone),
    (Short: 'v'; Long: 'version'; Argument: oaNone)
  );

procedure OptionProc(OptionNum: Integer; HasArgument: boolean;
  const Argument: string; const SeparateArgs: TSeparateArgs; Data: Pointer);
begin
 case OptionNum of
  0: begin
      InfoWrite(DisplayProgramName +
        ': small game based on an old DOS game "Color lines".' +nl+
        'Accepted command-line options:' +nl+
        HelpOptionHelp+ nl+
        VersionOptionHelp +nl+
        '  --fullscreen          Try to resize the screen to 640x480 and then' +nl+
        '                        run game in fullscreen window' +nl+
        Format('By default, game will run in window sized %dx%d.',
          [GameScreenWidth, GameScreenHeight]) +nl+
        nl+
        SCastleEngineProgramHelpSuffix(DisplayProgramName, Version, true));
      ProgramBreak;
     end;
  1: begin
      WritelnStr(Version);
      ProgramBreak;
     end;
  else raise EInternalError.Create('OptionProc');
 end;
end;

{ main program ------------------------------------------------------- }

const
  { musi byc mniejsze niz BoardWidth * BoardHeight }
  StartGamePiecesCount = 5;

var WantsToPlayMore: boolean = true;
    PlayerMove: TPlayerMove;
    PlayerMoveWay: TVector2IntegerList;
    i: Integer;
begin
 { parse params }
 Parameters.Parse(Options, @OptionProc, nil);
 if Parameters.High > 0 then
  raise EInvalidParams.Create('Invalid parameter "'+Parameters[1]+'"');

 { open glw (everything else about initing glw is done in LinesWindow) }
 Window.Open;

 try
  { Init CastleMessages }
  { For now don't change defaults of CastleMessages -- I like them. }
  { messageCols.RectBorderCol := White3Single; }
  { messageFont := LinesFont; }

  { go }
  InputAnyKey(Window, ImagesPath+ 'title.png', 0, 0, 0, 0);

  PlayerMoveWay := TVector2IntegerList.Create;
  repeat
   ClearGame(true, true, true);

   { nie sprawdzamy ponizej wyniku PutBallOnRandomEmptyBoardPos -
     wiemy ze StartGamePieces < BoardWidth*BoardHeight }
   for i := 1 to StartGamePiecesCount do
    PutBallOnRandomEmptyBoardPos(RandomBall);

   repeat
    case GetPlayerAction(PlayerMove, PlayerMoveWay) of
     paMove:
       begin
        BallMove(PlayerMove, PlayerMoveWay);
        if not EndGameTurn then
        begin
	 { Window.PostRedisplay zeby namalowal plansze gry z BallMove zakonczonym
	   i byc moze dodanymi niektorymi kulkami sposrod NextColors. }
         Window.PostRedisplay;
         MessageOK(Window, 'No more moves possible - game over !');
         break;
        end;
       end;
     paNewGame: break;
     paQuit: begin WantsToPlayMore := false; break end;
    end;
   until false;

   CheckAndMaybeAddToHighscore(PlayerScore);

  until not WantsToPlayMore;
 finally
  PlayerMoveWay.Free;
 end;
end.
