{
  Copyright 2003-2014 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Waiting for user input, keeping static image displayed on TCastleWindowCustom. }
unit CastleInputAny;

{
  TODO
  - Input i InputAnyKey powinny byc scalone w jedno,
    razem z ich callbackami, przynajmniej OnRender.
    Musza byc w stanie dobrze zareagowac na wypadek gdyby user
    zrobil resize na okienku.
}

{$I castleconf.inc}

interface

uses CastleGLUtils, CastleWindow, CastleWindowModes, CastleFonts, CastleUtils,
  CastleImages, CastleStringUtils, CastleGLImages;

{ Wait until user inputs a string (accept by Enter), displaying the static
  image with user string.

  ScreenX0, ScreenY0 is position for lower-left screen corner.

  AnswerX0, AnswerY0 is position for displaying user answer.

  AnswerDefault, MinLength, MaxLength and AnswerAllowedChars
  have the same meaning as in CastleMessages unit. Initial Answer
  cannot contain characters outside AnswerAllowedChars. }
function Input(
  Image: TGLImage;
  Font: TCastleFont;
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

  X, Y is the image position on the screen. In the background
  OpenGL clear color will be used.

  @groupBegin }
procedure InputAnyKey(const ImgURL: string;
  ResizeX, ResizeY, X, Y: Integer); overload;
procedure InputAnyKey(const Img: TCastleImage;
  X, Y: Integer); overload;
procedure InputAnyKey(Image: TGLImage;
  X, Y: Integer; BGImageWidth, BGImageHeight: Cardinal); overload;
{ @groupEnd }

implementation

uses SysUtils, CastleKeysMouse, CastleColors, LinesWindow;

{ window callbacks for Input ------------------------------------------------- }

type
  TWindowInputData = record
    { input params }
    Image: TGLImage;
    MinLength, MaxLength: Integer;
    AnswerAllowedChars: TSetOfChars;
    Font: TCastleFont;
    ScreenX0, ScreenY0, AnswerX0, AnswerY0: Integer;

    { input/output params }
    Answer: string;
    Answered: boolean;
  end;
  PWindowInputData = ^TWindowInputData;

procedure Render(Container: TUIContainer);
var D: PWindowInputData;
begin
 D := PWindowInputData(Window.UserData);

 D^.Image.Draw(D^.ScreenX0, D^.ScreenY0);
 D^.Font.Print(D^.AnswerX0, D^.AnswerY0, White, D^.Answer+'_');
end;

procedure Press(Container: TUIContainer; const Event: TInputPressRelease);
var D: PWindowInputData;
begin
  if Event.EventType <> itKey then Exit;

  D := PWindowInputData(Window.UserData);

  case Event.KeyCharacter of
    CharBackSpace:
      if Length(D^.Answer) > 0 then
      begin
        SetLength(D^.Answer, Length(D^.Answer)-1);
        Window.Invalidate;
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
        Window.Invalidate;
      end;
  end;
end;

{ Input ---------------------------------------------------------------------- }

function Input(
  Image: TGLImage;
  Font: TCastleFont;
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

  SavedMode := TGLMode.CreateReset(Window, @Render, nil, @NoClose);
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
    X, Y: Integer;
  end;
  PInputAnyKeyData = ^TInputAnyKeyData;

procedure RenderGLAnyKey(Container: TUIContainer);
var
  D: PInputAnyKeyData;
begin
  D := PInputAnyKeyData(Window.UserData);
  if D^.DoClear then GLClear([cbColor], Black);
  D^.Image.Draw(D^.X, D^.Y);
end;

procedure PressAnyKey(Container: TUIContainer; const Event: TInputPressRelease);
var D: PInputAnyKeyData;
begin
  if Event.EventType = itKey then
  begin
    D := PInputAnyKeyData(Window.UserData);
    D^.KeyPressed := true;
  end;
end;

{ InputAnyKey ---------------------------------------------------------------- }

procedure InputAnyKey(Image: TGLImage;
  X, Y: Integer; BGImageWidth, BGImageHeight: Cardinal);
var
  Data: TInputAnyKeyData;
  savedMode: TGLMode;
begin
 SavedMode := TGLMode.CreateReset(Window, @RenderGLAnyKey, nil, @NoClose);
 try
  Data.DoClear := (Cardinal(Window.Width ) > BGImageWidth ) or
                  (Cardinal(Window.Height) > BGImageHeight);
  Data.Image := Image;
  Data.Image.Alpha := acNone;
  Data.KeyPressed := false;
  Data.X := X;
  Data.Y := Y;

  Window.UserData := @Data;
  Window.OnPress := @PressAnyKey;

  repeat Application.ProcessMessage(true, true) until Data.KeyPressed;
 finally SavedMode.Free end;
end;

procedure InputAnyKey(const Img: TCastleImage;
  X, Y: Integer);
var
  I: TGLImage;
begin
  I := TGLImage.Create(Img);
  try
    InputAnyKey(I, X, Y, Img.Width, Img.Height);
  finally FreeAndNil(I) end;
end;

procedure InputAnyKey(const ImgURL: string;
  ResizeX, ResizeY, X, Y: Integer);
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
    InputAnyKey(GLImage, X, Y, BGImageWidth, BGImageHeight);
  finally FreeAndNil(GLImage) end;
end;

end.
