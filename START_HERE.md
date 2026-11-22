# teletext-slojd: start here

Teletext "slojd" (craft): a MODE 7 canvas editor for the BBC Micro that records every keystroke so a
drawing can be played back as an animation. The canvas is larger than the screen and scrolls; function
keys pick colours and letter keys map to sixel graphics. A 2017 6502 tool (beebasm).

| | |
|---|---|
| GitHub | https://github.com/kieranhj/teletext-slojd (public) |
| Local path | D:\beeb\mine\teletext-slojd (moved from OneDrive\BEEB\Repos\teletext-slojd on 2026-11-22) |
| Branch | `master`; other branches: `wip/2026-11-tidy` (snapshot, see below) |
| Last commit | 2017-03-02: Added Raquel's work from Cambridge |

## What's in here
- `teletext-slojd.asm` - the editor (compile-time options at the top: `_LOAD_ON_START`, `_ENABLE_PIXEL_EDIT`, ...).
- `teletext-slojd.ssd` - the built disc (committed); `cambridge disc.ssd` - a disc with Raquel's work from Cambridge.
- `$.raq2`, `$.raq3` (+ `.inf`) - recorded keystroke files (Raquel's drawings).
- `keyboard map pixel.png` - the key-to-sixel map.
- `make.bat` (build), `run.bat` (B-em). `compile.txt` is the listing (gitignored).

## Build and run
- `make`: runs `make.bat`: `..\..\Bin\beebasm.exe -i teletext-slojd.asm -do teletext-slojd.ssd -boot TTSLOJD -v`.
  The rebuilt `teletext-slojd.ssd` is byte-identical to the committed one.
- Tools: beebasm from D:\beeb\Bin (via `..\..\Bin`).
- Run: `run.bat` opens the disc in B-em; SHIFT+BREAK boots the editor, Escape for the menu (load, save, play, new).

## Local changes
- Untracked: `teletext-slojd.txt` - design notes and a to-do / bugs list (90 lines). A copy is committed on
  `wip/2026-11-tidy` (pushed to origin 2026-11-21). Worth committing to `master`.
- New, uncommitted: `Makefile`, `START_HERE.md`.

## Status and next steps
- Left in March 2017. From `teletext-slojd.txt`: open bugs "getting a bit slow with a larger canvas";
  ideas "save screen as a file (for export)", "screen import into the keypress buffer"; moving lower in
  memory for a bigger buffer "Model B didn't seem to like it".

## See also
- `teletext-slojd.txt` (notes). Related on D: `D:\beeb\mine\teletext-canvas`, `D:\beeb\mine\teletextr`.
