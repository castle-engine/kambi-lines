{
  Copyright 2003-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Waiting for user input, keeping static image displayed. }
unit CastleInputAny;

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
  Image: TDrawableImage;
  Font: TCastleFont;
  ScreenX0, ScreenY0, AnswerX0, AnswerY0: Integer;
  AnswerDefault: string = '';
  MinLength: Integer = 0;
  MaxLength: Integer = 0;
  const AnswerAllowedChars: TSetOfChars = AllChars
  ): string;

{ Wait until user presses a key or mouse button.

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
procedure InputAnyKey(Image: TDrawableImage;
  X, Y: Integer; BGImageWidth, BGImageHeight: Cardinal); overload;
{ @groupEnd }

implementation

uses SysUtils,
  CastleKeysMouse, CastleColors, CastleRenderContext, CastleUiControls,
  LinesWindow;

{ TODO: merge Input and InputAnyKey implementations into one,
  merge TInputView and TInputAnyKeyView into one class. }

{ View for Input ------------------------------------------------------------- }

type
  TInputView = class(TCastleView)
  public
    { input params }
    Image: TDrawableImage;
    MinLength, MaxLength: Integer;
    AnswerAllowedChars: TSetOfChars;
    Font: TCastleFont;
    ScreenX0, ScreenY0, AnswerX0, AnswerY0: Integer;

    { input/output params }
    Answer: string;
    Answered: boolean;

    procedure Render; override;
    function Press(const Event: TInputPressRelease): Boolean; override;
  end;

procedure TInputView.Render;
begin
  inherited;
  Image.Draw(ScreenX0, ScreenY0);
  Font.Print(AnswerX0, AnswerY0, White, Answer+'_');
end;

function TInputView.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  if Result then Exit;

  if Event.EventType <> itKey then Exit;

  case Event.KeyCharacter of
    CharBackSpace:
      if Length(Answer) > 0 then
      begin
        SetLength(Answer, Length(Answer)-1);
        Window.Invalidate;
      end;
    CharEnter:
      if Between(Length(Answer), MinLength, MaxLength) then
        Answered := true;
    else
      if (Event.KeyCharacter <> #0) and
         (Event.KeyCharacter in AnswerAllowedChars) and
         (Length(Answer) < MaxLength) then
      begin
        Answer += Event.KeyCharacter;
        Window.Invalidate;
      end;
  end;
end;

{ Input ---------------------------------------------------------------------- }

function Input(
  Image: TDrawableImage;
  Font: TCastleFont;
  ScreenX0, ScreenY0, AnswerX0, AnswerY0: Integer;
  AnswerDefault: string = '';
  MinLength: Integer = 0;
  MaxLength: Integer = 0;
  const AnswerAllowedChars: TSetOfChars = AllChars
  ): string;
var
  SavedMode: TGLMode;
  View: TInputView;
begin
  View := TInputView.Create(nil);
  try
    View.Image := Image;
    View.Answer := AnswerDefault;
    View.MinLength := MinLength;
    View.MaxLength := MaxLength;
    View.AnswerAllowedChars := AnswerAllowedChars;
    View.Answered := false;
    View.Font := Font;
    View.ScreenX0 := ScreenX0;
    View.ScreenY0 := ScreenY0;
    View.AnswerX0 := AnswerX0;
    View.AnswerY0 := AnswerY0;

    SavedMode := TGLMode.CreateReset(Window);
    try
      Window.Container.PushView(View);
      repeat
        Application.ProcessMessage(true, true)
      until View.Answered;
      Result := View.Answer;
      Window.Container.PopView(View);
    finally FreeAndNil(SavedMode) end;
  finally FreeAndNil(View) end;
end;

{ window callbacks for InputAnyKey ------------------------------------------- }

type
  TInputAnyKeyView = class(TCastleView)
  public
    DoClear: boolean;
    Image: TDrawableImage;
    KeyPressed: boolean;
    X, Y: Integer;

    procedure Render; override;
    function Press(const Event: TInputPressRelease): Boolean; override;
  end;

procedure TInputAnyKeyView.Render;
begin
  inherited;
  if DoClear then RenderContext.Clear([cbColor], Black);
  Image.Draw(X, Y);
end;

function TInputAnyKeyView.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  if Result then Exit;

  if Event.EventType in [itKey, itMouseButton] then
  begin
    KeyPressed := true;
  end;
end;

{ InputAnyKey ---------------------------------------------------------------- }

procedure InputAnyKey(Image: TDrawableImage;
  X, Y: Integer; BGImageWidth, BGImageHeight: Cardinal);
var
  View: TInputAnyKeyView;
  savedMode: TGLMode;
begin
  View := TInputAnyKeyView.Create(nil);
  try
    SavedMode := TGLMode.Create(Window);
    try
      View.DoClear := (Cardinal(Window.Width ) > BGImageWidth ) or
                      (Cardinal(Window.Height) > BGImageHeight);
      View.Image := Image;
      View.Image.Alpha := acNone;
      View.KeyPressed := false;
      View.X := X;
      View.Y := Y;

      Window.Container.PushView(View);
      repeat
        Application.ProcessMessage(true, true);
      until View.KeyPressed;
      Window.Container.PopView(View);
    finally FreeAndNil(SavedMode) end;
  finally FreeAndNil(View) end;
end;

procedure InputAnyKey(const Img: TCastleImage;
  X, Y: Integer);
var
  I: TDrawableImage;
begin
  I := TDrawableImage.Create(Img, true, false);
  try
    InputAnyKey(I, X, Y, Img.Width, Img.Height);
  finally FreeAndNil(I) end;
end;

procedure InputAnyKey(const ImgURL: string;
  ResizeX, ResizeY, X, Y: Integer);
var
  GLImage: TDrawableImage;
  Image: TCastleImage;
  BGImageWidth, BGImageHeight: Cardinal;
begin
  Image := LoadImage(ImgURL, [TRGBImage], ResizeX, ResizeY);
  try
    BGImageWidth  := Image.Width ;
    BGImageHeight := Image.Height;
    GLImage := TDrawableImage.Create(Image, true, false);
    try
      InputAnyKey(GLImage, X, Y, BGImageWidth, BGImageHeight);
    finally FreeAndNil(GLImage) end;
  finally FreeAndNil(Image) end;
end;

end.
