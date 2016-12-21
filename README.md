Microraptor lua

lua bindings for microraptor gui, and a full multi-tasking user interface
written using them. 

[Watch a video of a live demonstration of micro raptor lua](https://www.youtube.com/watch?v=KsU3he_8nSE)

The files should be possible to run straight out of this directory with a
system installed luajit.

Each of the executables can be run stand-alone, or under mrg, the
mrg-text-editor is used by mrg-files for showing and editing text-files.
The image viewer should be able to show lua applications written for zn, as the live things they are, when a given extension is used. For thumbnailing purposes, running the application headlessly for 10seconds and snapshotting if it keeps changing/busy also seems reasonable.
mrl-shell - a graphical multi-tasking shell
mrl-view - a filesystem browser; using child processes for viewing files
mrl-text-editor    - a minimal text editor; used by mrg-files
mrl-lyd-synth      - piano with realtime synth with editable code
mrl-flipgame  - the game often known as reversi or othello
mrl-game-paddlewar - basic two player touch implementation of pong

mrg.lua - the luajit ffi binding for microraptor gui
cairo_h.lua cairo.lua - cairo binding to be used along with the microraptor binding


To use this you need the following installed:
  cairo (pixman, libpng, zlib, fontconfig, freetype)
  mmm (sdl)
  mrg (mmm, gtk)
