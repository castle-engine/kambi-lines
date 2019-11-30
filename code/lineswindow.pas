{
  Copyright 2003-2017 Michalis Kamburelis.

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

unit LinesWindow;

{ zajmujemy sie tutaj naszym okienkiem TCastleWindowBase. Tutaj inicjujemy mu wszystkie
  wlasciwosci, parsujemy jego parametry i robimy mu Init. Tutaj zajmujemy
  sie tez projection OpenGLa ktore bedzie jedno i takie samo przez caly czas
  gry.

  Zalozenia na ktorych moga/musza polegac inne moduly :
  - projection OpenGLa ustala odpowiedniosc 1-1 miedzy jednostkami OpenGLa
    a iloscia faktycznych pixeli na ekranie
  - moj kod powinien rysowac tylko po powierzchni OpenGLa w zakresie
    0..GameWidth, 0..GameHeight ograniczajac sie do wywolywania
    GLClear([cbDepth], ...) aby wyczyscic reszte ekranu

  Ten modul NIE zalezy od zadnego innego modulu sposrod modulow kulek.
  Ten modul jest na samym spodzie.
}

interface

uses CastleWindow, CastleVectors, CastleFonts;

var
  Window: TCastleWindowBase;

function ImagesPath: string;

const
  GameScreenWidth = 640;
  GameScreenHeight = 350;

implementation

uses SysUtils, CastleUtils, CastleGLUtils, CastleParameters, CastleFilesUtils,
  CastleWindowModes;

function ImagesPath: string;
begin result := 'castle-data:/images/' end;

(* We used to have here a code that was adjusting 2D projection
   to scale everything to screen size.
   It is not used anymore, our 2D controls depend on a pixel-per-pixel
   2D projection that is set automatically.

procedure OpenGL(Container: TUIContainer);
var OverflowX, FirstOverflowX, SecondOverflowX,
    OverflowY, FirstOverflowY, SecondOverflowY: Integer;
begin
  { place GameScreenWidth, GameScreenHeight in the midle of Window.Width, Window.Height. }

  OverflowX := Window.Width-GameScreenWidth;
  FirstOverflowX := OverflowX div 2;
  SecondOverflowX := OverflowX - FirstOverflowX;

  OverflowY := Window.Height-GameScreenHeight;
  FirstOverflowY := OverflowY div 2;
  SecondOverflowY := OverflowY - FirstOverflowY;

  OrthoProjection(-FirstOverflowX, GameScreenWidth + SecondOverflowX,
                  -FirstOverflowY, GameScreenHeight + SecondOverflowY);

  FScreenX0 := -FirstOverflowX;
  FScreenY0 := -FirstOverflowY;
end;
*)

{ initialize ----------------------------------------------------------------- }

var WasParam_Fullscreen: boolean;

const
  Options: array[0..0]of TOption =
  ( (Short:#0; Long:'fullscreen'; Argument: oaNone) );

procedure OptionProc(ParamNum: Integer; HasArgument: boolean;
  const Argument: string; const SeparateArgs: TSeparateArgs; Data: Pointer);
begin
  WasParam_Fullscreen := true;
end;

procedure Open;
begin
  Window := TCastleWindowBase.Create(nil);
  // this background would cover our LinesMove rendering
  Window.Container.BackgroundEnable := false;

  { parse params }
  WasParam_Fullscreen := false;
  Parameters.Parse(Options, @OptionProc, nil, true);

  { setup Window parameters Width, Height, Fullscreen, ResizeAllowed
    + Application.VideoResize* }
  if WasParam_Fullscreen then
  begin
    Application.VideoResize := true;
    Application.VideoResizeWidth := 640;
    Application.VideoResizeHeight := 480;
    Application.VideoChange(true);

    Window.Width := Application.VideoResizeWidth;
    Window.Height := Application.VideoResizeHeight;
    Window.FullScreen := true;
  end else
  begin
    Window.Width := GameScreenWidth;
    Window.Height := GameScreenHeight;
  end;

  Window.ResizeAllowed := raNotAllowed; { so no OnResize callback is needed }

  { open glw window (samo Window.Open przerzucamy do zasadniczego kambi_lines.lpr,
    lepiej nie polegac na kolejnosci wywolywania Initialization modulow,
    fpc cos sie w tym pieprzy) }
  Window.Caption := 'Kambi Lines';
  Window.OnCloseQuery := @NoClose;
end;

initialization
  Open;
finalization
  FreeAndNil(Window);
end.
