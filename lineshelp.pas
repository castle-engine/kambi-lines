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

unit LinesHelp;

interface

procedure ShowHelp;

implementation

uses SysUtils, LinesWindow, KambiUtils, GLWinMessages, LinesGame;

procedure ShowHelp;
begin
 MessageOK(Window,
   'Keys: besides the keys listed at the bottom of the screen, ' +
   'also available are:' + nl +
   '  H = show highscores' + nl +
   '  Escape = exit' + nl +
   nl+
   SVrmlEngineProgramHelpSuffix(DisplayProgramName, Version, false),
   taLeft);
end;

end.
