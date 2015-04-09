Microraptor lua

lua bindings for microraptor gui, and a full multi-tasking user interface
written using them. The files should be possible to run straight out of this
directory with a system installed luajit.

Each of the executables can be run stand-alone, or under mrg, the
mrg-text-editor is used by mrg-files for showing and editing text-files.

mrg-shell - a graphical multi-tasking shell
mrg-files - a filesystem browser; using child processes for viewing files
mrg-text-editor    - a minimal text editor; used by mrg-files
mrg-lyd-synth      - piano with realtime synth with editable code
mrg-game-flipgame  - the game often known as reversi or othello
mrg-game-paddlewar - basic two player touch implementation of pong

mrg.lua - the luajit ffi binding for microraptor gui
cairo_h.lua cairo.lua - cairo binding to be used along with the microraptor binding


To use this you need the following installed:
  cairo (pixman, libpng, zlib, fontconfig, freetype)
  mmm (sdl)
  mrg (mmm, gtk)
