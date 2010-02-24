#! /bin/bash
set -eu

# Make fonts sources used only by kambi_lines.

do_font2pascal ()
{
  font2pascal "$@" --dir .
}

do_font2pascal --font-name 'Christmas Card' --font-height -24 --grab-to bfnt

do_font2pascal --font-name 'Bitstream Vera Sans' --font-height -14 --grab-to bfnt -b 1

do_font2pascal --font-name 'Arial CE / Latin 2' --font-height -14 --grab-to bfnt -b 0 \
  --font-charset ANSI_CHARSET
