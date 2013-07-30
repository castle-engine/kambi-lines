{
  Copyright 2003-2013 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Waiting for user input, keeping static image displayed on TCastleWindowBase. }
unit CastleInputAny;

{
  TODO
  - Input i InputAnyKey powinny byc scalone w jedno,
    razem z ich callbackami, przynajmniej OnDraw.
    Musza byc w stanie dobrze zareagowac na wypadek gdyby user
    zrobil resize na okienku.
}

{$I castleconf.inc}

interface

uses GL, GLU, CastleGLUtils, CastleWindow, CastleWindowModes, CastleGLBitmapFonts, CastleUtils,
  CastleImages, CastleStringUtils, CastleGLImages;

{ Wait until user inputs a string (accept by Enter), displaying the static
  image with user string.

  ScreenX0, ScreenY0 is raster position for lower-left screen corner.

  AnswerX0, AnswerY0 is raster position for displaying user answer.

  AnswerDefault, MinLength, MaxLength and AnswerAllowedChars
  have the same meaning as in CastleMessages unit. Initial Answer
  cannot contain characters outside AnswerAllowedChars. }
function Input(Window: TCastleWindowBase;
  Image: TGLImage;
  Font: TGLBitmapFontAbstract;
  ScreenX0, ScreenY0, AnswerX0, AnswerY0: Integer;
  AnswerDefault: string = '';
  MinLength: Integer = 0;
  MaxLength: Integer = 0;
  const AnswerAllowedChars: TSetOfChars = AllChars
  ): string;

{ Wait until user presses a key.

  Displays a given image on the screen while waiting.
  You can give image URL, or ready TCastleImage instance
  (must be renderable to OpenGL, i.e. by one of CastleGLImages.PixelsImageClasses
  classes), or display list to render any image (in which case you
  have to tell us image size).

  RasterX, RasterY is the image position on the screen. In the background
  OpenGL clear color will be used.

  @groupBegin }
procedure InputAnyKey(Window: TCastleWindowBase; const ImgURL: string;
  ResizeX, ResizeY, RasterX, RasterY: Integer); overload;
procedure InputAnyKey(Window: TCastleWindowBase; const Img: TCastleImage;
  RasterX, RasterY: Integer); overload;
procedure InputAnyKey(Window: TCastleWindowBase; Image: TGLImage;
  RasterX, RasterY: Integer; BGImageWidth, BGImageHeight: Cardinal); overload;
{ @groupEnd }

implementation

uses SysUtils, CastleKeysMouse;

{ window callbacks for Input ------------------------------------------------- }

type
  TWindowInputData = record
    { input params }
    Image: TGLImage;
    MinLength, MaxLength: Integer;
    AnswerAllowedChars: TSetOfChars;
    Font: TGLBitmapFontAbstract;
    ScreenX0, ScreenY0, AnswerX0, AnswerY0: Integer;

    { input/output params }
    Answer: string;
    Answered: boolean;
  end;
  PWindowInputData = ^TWindowInputData;

procedure Draw(Window: TCastleWindowBase);
var D: PWindowInputData;
begin
 D := PWindowInputData(Window.UserData);

 glRasterPos2i(D^.ScreenX0, D^.ScreenY0);
 D^.Image.Draw;
 glRasterPos2i(D^.AnswerX0, D^.AnswerY0);
 D^.Font.Print(D^.Answer+'_');
end;

procedure Press(Window: TCastleWindowBase; const Event: TInputPressRelease);
var D: PWindowInputData;
begin
  if Event.EventType <> itKey then Exit;

  D := PWindowInputData(Window.UserData);

  case Event.KeyCharacter of
    CharBackSpace:
      if Length(D^.Answer) > 0 then
      begin
        SetLength(D^.Answer, Length(D^.Answer)-1);
        Window.PostRedisplay;
      end;
    CharEnter:
      if Between(Length(D^.Answer), D^.MinLength, D^.MaxLength) then
        D^.Answered := true;
    else
      if (Event.KeyCharacter <> #0) and
         (Event.KeyCharacter in D^.AnswerAllowedChars) and
         (Length(D^.Answer) < D^.MaxLength) then
      begin
        D^.Answer += Event.KeyCharacter;
        Window.PostRedisplay;
      end;
  end;
end;

{ Input ---------------------------------------------------------------------- }

function Input(Window: TCastleWindowBase;
  Image: TGLImage;
  Font: TGLBitmapFontAbstract;
  ScreenX0, ScreenY0, AnswerX0, AnswerY0: Integer;
  AnswerDefault: string = '';
  MinLength: Integer = 0;
  MaxLength: Integer = 0;
  const AnswerAllowedChars: TSetOfChars = AllChars
  ): string;
var
  SavedMode: TGLMode;
  Data: TWindowInputData;
begin
  Data.Image := Image;
  Data.Answer := AnswerDefault;
  Data.MinLength := MinLength;
  Data.MaxLength := MaxLength;
  Data.AnswerAllowedChars := AnswerAllowedChars;
  Data.Answered := false;
  Data.Font := Font;
  Data.ScreenX0 := ScreenX0;
  Data.ScreenY0 := ScreenY0;
  Data.AnswerX0 := AnswerX0;
  Data.AnswerY0 := AnswerY0;

  SavedMode := TGLMode.CreateReset(Window, 0, false, @Draw, nil, @NoClose);
  try
    Window.UserData := @Data;
    Window.OnPress := @Press;

    repeat Application.ProcessMessage(true, true) until Data.Answered;

    result := Data.Answer;
  finally SavedMode.Free end;
end;

{ window callbacks for InputAnyKey ------------------------------------------- }

type
  TInputAnyKeyData = record
    DoClear: boolean;
    Image: TGLImage;
    KeyPressed: boolean;
  end;
  PInputAnyKeyData = ^TInputAnyKeyData;

procedure DrawGLAnyKey(Window: TCastleWindowBase);
var D: PInputAnyKeyData;
begin
 D := PInputAnyKeyData(Window.UserData);
 if D^.DoClear then glClear(GL_COLOR_BUFFER_BIT);
 D^.Image.Draw;
end;

procedure PressAnyKey(Window: TCastleWindowBase; const Event: TInputPressRelease);
var D: PInputAnyKeyData;
begin
  if Event.EventType = itKey then
  begin
    D := PInputAnyKeyData(Window.UserData);
    D^.KeyPressed := true;
  end;
end;

{ InputAnyKey ---------------------------------------------------------------- }

procedure InputAnyKey(Window: TCastleWindowBase; Image: TGLImage;
  RasterX, RasterY: Integer; BGImageWidth, BGImageHeight: Cardinal);
var
  Data: TInputAnyKeyData;
  savedMode: TGLMode;
begin
 SavedMode := TGLMode.CreateReset(Window, GL_COLOR_BUFFER_BIT, false,
   @DrawGLAnyKey, nil, @NoClose);
 try
  glDisable(GL_ALPHA_TEST);

  Data.DoClear := (Cardinal(Window.Width ) > BGImageWidth ) or
                  (Cardinal(Window.Height) > BGImageHeight);
  Data.Image := Image;
  Data.KeyPressed := false;

  Window.UserData := @Data;
  Window.OnPress := @PressAnyKey;

  glRasterPos2i(RasterX, RasterY);
  repeat Application.ProcessMessage(true, true) until Data.KeyPressed;
 finally SavedMode.Free end;
end;

procedure InputAnyKey(Window: TCastleWindowBase; const Img: TCastleImage;
  RasterX, RasterY: Integer);
var
  I: TGLImage;
begin
  I := TGLImage.Create(Img);
  try
    InputAnyKey(Window, I, RasterX, RasterY, Img.Width, Img.Height);
  finally FreeAndNil(I) end;
end;

procedure InputAnyKey(Window: TCastleWindowBase; const ImgURL: string;
  ResizeX, ResizeY, RasterX, RasterY: Integer);
var
  GLImage: TGLImage;
  Image: TCastleImage;
  BGImageWidth, BGImageHeight: Cardinal;
begin
  Image := LoadImage(ImgURL, [TRGBImage], ResizeX, ResizeY);
  try
    BGImageWidth  := Image.Width ;
    BGImageHeight := Image.Height;
    GLImage := TGLImage.Create(Image);
  finally FreeAndNil(Image) end;
  try
    InputAnyKey(Window, GLImage, RasterX, RasterY, BGImageWidth, BGImageHeight);
  finally FreeAndNil(GLImage) end;
end;

end.
