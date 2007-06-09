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

unit LinesWindow;

{ zajmujemy sie tutaj naszym okienkiem TGLWindow. Tutaj inicjujemy mu wszystkie
  wlasciwosci, parsujemy jego parametry i robimy mu Init. Tutaj zajmujemy
  sie tez projection OpenGLa ktore bedzie jedno i takie samo przez caly czas
  gry.

  Zalozenia na ktorych moga/musza polegac inne moduly :
  - projection OpenGLa ustala odpowiedniosc 1-1 miedzy jednostkami OpenGLa
    a iloscia faktycznych pixeli na ekranie
  - moj kod powinien rysowac tylko po powierzchni OpenGLa w zakresie
    0..GameWidth, 0..GameHeight ograniczajac sie do wywolywania
    glClear(GL_COLOR_BUFFER_BIT) aby wyczyscic reszte ekranu na domyslny
    clear color
    
  Ten modul NIE zalezy od zadnego innego modulu sposrod modulow kulek.
  Ten modul jest na samym spodzie.
}

interface

uses GLWindow, VectorMath, OpenGLBmpFonts;

var
  glw: TGLWindow;
  { LinesFont uzywany jest w wielu miejscach gry - w DrawGame (do tekstu
    przyciskow i score points), w kambi_lines.dpr ustawiamy go GLWinMessages,
    i w Highscores w DrawHighscore; }
  LinesFont: TGLBitmapFont;

function ImagesPath: string;

const
  GameScreenWidth = 640;
  GameScreenHeight = 350;
  
{ pozycje lewego dolnego rogu ekranu we wspolrzednych OpenGL'a.
  Beda zawsze <= 0 - jezeli wymiary GameScreen sa rowne wymiarom glwindow
  to beda rowne 0 ale moga byc mniejsze od zera jezeli glwindow bedzie
  wieksze niz GameScreen. Ustalane dopiero w czasie InitGL okienka glwindow . }
function ScreenX0: Integer;
function ScreenY0: Integer;

implementation

uses SysUtils, KambiUtils, OpenGLh, KambiGLUtils, 
  BFNT_ArialCELatin2_m14_Unit, ParseParametersUnit, KambiFilesUtils;

var
  FScreenX0, FScreenY0: Integer;
  
function ScreenX0: Integer; begin result := FScreenX0 end;
function ScreenY0: Integer; begin result := FScreenY0 end;

{ cos do Images ------------------------------------------------------------ }

function ImagesPath: string;
begin result := ProgramDataPath +'images' +PathDelim end;

{ gl window callbacks --------------------------------------------------------- }

procedure InitGL(glwin: TGLWindow);
var OverflowX, FirstOverflowX, SecondOverflowX,
    OverflowY, FirstOverflowY, SecondOverflowY: Integer;
begin
 { musi byc , moj kod na tym polega. Ponizsze projection stara sie umiescic
   GameScreenWidth, GameScreenHeight na srodku glwin.Width, glwin.Height.
 }
 OverflowX := glwin.Width-GameScreenWidth;
 FirstOverflowX := OverflowX div 2;
 SecondOverflowX := OverflowX - FirstOverflowX;

 OverflowY := glwin.Height-GameScreenHeight;
 FirstOverflowY := OverflowY div 2;
 SecondOverflowY := OverflowY - FirstOverflowY;

 ProjectionGLOrtho(-FirstOverflowX, GameScreenWidth + SecondOverflowX,
                   -FirstOverflowY, GameScreenHeight + SecondOverflowY);

 FScreenX0 := -FirstOverflowX;
 FScreenY0 := -FirstOverflowY;
 
 LinesFont := TGLBitmapFont.Create(@BFNT_ArialCELatin2_m14);
end;

procedure CloseQueryGL(glwin: TGLWindow); begin end;

procedure CloseGL(glwin: TGLWindow);
begin
 FreeAndNil(LinesFont);
end;

{ unit Init/Fini --------------------------------------------------------- }

var WasParam_Fullscreen: boolean;

const
  Options: array[0..0]of TOption = 
  ( (Short:#0; Long:'fullscreen'; Argument: oaNone) );

  procedure OptionProc(ParamNum: Integer; HasArgument: boolean;
    const Argument: string; const SeparateArgs: TSeparateArgs; Data: Pointer);
  begin
   WasParam_Fullscreen := true;
  end;

procedure Init;
begin
 glw := TGLWindow.Create;

 { parse params }
 WasParam_Fullscreen := false;
 ParseParameters(Options, @OptionProc, nil, true);

 { setup glwin parameters Width, Height, Fullscreen, ResizeAllowed
   + glwm.VideoResize* }
 if WasParam_Fullscreen then
 begin
  glwm.VideoResize := true;
  glwm.VideoResizeWidth := 640;
  glwm.VideoResizeHeight := 480;
  glwm.VideoChange(true);
  
  glw.Width := glwm.VideoResizeWidth;
  glw.Height := glwm.VideoResizeHeight;
  glw.FullScreen := true;
 end else
 begin
  glw.Width := GameScreenWidth;
  glw.Height := GameScreenHeight;
 end;

 glw.ResizeAllowed := raNotAllowed; { so no OnResize callback is needed }
 
 { Init glw window (samo glw.Init przerzucamy do zasadniczego kambi_lines.dpr,
   lepiej nie polegac na kolejnosci wywolywania Initialization modulow,
   fpc cos sie w tym pieprzy) }
 glw.Caption := 'Kambi Lines';
 glw.OnCloseQuery := @CloseQueryGL;
 glw.OnInit := @InitGL;
 glw.OnClose := @CloseGL;
end;

initialization
 Init;
finalization
 FreeAndNil(glw);
end.
