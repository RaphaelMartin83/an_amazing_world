# An Amazing World

A Crash-Bandicoot-style 3D platformer built with **Godot 4.7** — starring a cartoon **Palmouze**, whose attack is... a fart.
Everything (engine, export templates, tools) lives in a Docker image; nothing is installed on the host.

## Play

* Windows: `build/windows/AnAmazingWorld.exe` (single file) — or `build/AnAmazingWorld-windows.zip` to send it.
* Linux: `build/linux/AnAmazingWorld.x86_64`

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD / arrows | left stick / d-pad |
| Jump (press again in the air = double jump) | Space / K | A |
| **Fart attack** (360° gas cloud, same area as Crash's spin; also glides a little in the air) | J / X / Shift / left click | X / Y |
| Slide (jump out of it = long jump) | C / Ctrl / L | B / R1 |
| Body slam (slide button in mid-air) | C / Ctrl | B |
| Pause / restart level | Esc / R | Start / Back |

**Jumping to a level** (handy for trying new levels): pick it on the title screen (A/D or arrows, or press `1`-`9`),
press `1`-`9` in the pause menu (Esc) to restart the run at that level, or start directly in one from the command line:
`AnAmazingWorld.exe -- --level=3` (1 to 9) (Linux: `./AnAmazingWorld.x86_64 -- --level=3`).

**Crates:** wooden (smash for a beer) · `^` bounce (jump on it up to 5 times) · `C` checkpoint ·
`M` shield (survives one hit) · friend's face = extra life · grey iron (indestructible, stand on it) ·
`BOOM` (starts a 3-2-1 fuse with a blinking countdown, then a proper explosion that hurts you, wrecks neighbouring crates and kills enemies — run!).
**Gems:** every bounce crate has a gem floating above it — hold jump when you land on the crate to bounce high enough to grab it (+10 beers).
**Beers:** small bottles to collect. 100 = extra life... and Palmouze pukes (a second of retching with a green face, a spray and a puddle — purely cosmetic: he keeps full control the whole time). **Enemies:** crabs can be stomped or spun; purple spiky ones only by spinning/sliding.

Levels: 1 *Jungle Run* (gaps, moving platforms, spinning toys) · 2 *Boulder Rush* (outrun the boulder; camera in front) · 3 *Don Humo* (boss fight: a giant cigar, see below) · 4 *Sewer Surge* (brick tunnel over toxic sludge: slimes, crumbling grates that drop ~0.5 s after you land, moving platforms, spinners) ·
5 *Neon Rooftops* (sunset city: a conveyor belt that carries you forward, faster, hovering drones, scaffolding) ·
6 *Sunny Shores* (beach: tidal waves — foam warns you first — rotting pier planks, rafts, crabs, urchins) ·
7 *Frozen Peaks* (snow: slippery ice, cracking ice, ice floes, penguins, falling snow) ·
8 *Palmouze Airways* (a plane level, see below) ·
9 *The Brewmaster* (boss fight, see below).

**Boss — Don Humo** (level 3, a giant lit cigar in a smoky lounge). Attacks, always in this order: **ember rain** (red
circles on the floor warn where burning embers will land; the fire patches stay for a few seconds — jump or run), a **flame
sweep** (he spins breathing a wall of fire along the floor — jump it) and a **rolling smash** (he lies down and rolls across
the arena like a log — sidestep, he ends up crashing into the wall). After the flame sweep he **overheats**: he slumps on his
back with his tip glowing. That is the only opening: **fart right next to the glowing tip** (fart + flame = boom). Each hit
burns the cigar shorter, so he shrinks and gets faster. Four hits; if you die he keeps his damage.

**Palmouze Airways** (level 8): Palmouze flies a little red biplane (the engine runs on farts: green exhaust) and has to
avoid obstacles — floating rocks, seagulls, hot-air balloons, storm-cloud walls with a gap, windmills with spinning blades,
Don Humo's cigar blimps and big spinning propeller gates. Steer with WASD / arrows / left stick (the plane flies forward by
itself and speeds up). The **fart button does a barrel roll**: a burst of green gas, a speed boost and a short moment where
you pass through obstacles (cooldown ~2 s). Fly through the golden rings for checkpoints, grab the beers on the way, and
finish through the rainbow arch. A shield (if you have one) absorbs one crash.

**The ending:** beating the last boss (and walking into his portal) plays the birthday credits: a huge animated
"HAPPY BIRTHDAY PALMOUZE" with confetti, beer bottles, fireworks and a "Happy Birthday" tune, then *Starring: Palmouze*,
*Made by: Love for Palmouze*, *Inspired by: Palmouze*, then the "THE END" screen. Enter skips. (The name comes from
`game/scripts/friend_config.gd`; the credits text is in `game/scripts/credits.gd`.)

**Boss — The Brewmaster** (a giant angry beer keg with beer-mug fists). He repeats three attacks in the same order, so
they can be learned: **foam shots** (his mouth glows first; dodge them or pop them with a fart), a **leaping slam**
(it lands where you were standing and sends a shockwave ring along the floor — jump over it), and a **spinning charge**
at you that ends against the wall. After the charge he is **dizzy** (stars over his head): that is the only time he can
be hurt — fart him or stomp his foam crown. Three hits; every hit makes him faster. If you die the fight resumes with his
remaining health. Beating him showers you with beers and opens the exit portal.

## Tweak the hero (Palmouze)

Edit **`game/scripts/friend_config.gd`** — name, skin tone, hair style/colour, beard, moustache, glasses, eye colour,
clothes, cap/headband, head size, nose size … The 3D model, the HUD face icon and the extra-life crates all follow it.

## Build

```bash
tools/build.sh          # image + self-test (a bot plays both levels) + Windows & Linux exports
tools/build.sh quick    # same without the self-test
tools/screenshots.sh    # preview renders -> build/shots/
tools/godot.sh godot --headless --path game -- --selftest   # run the tests only
```

Windows builds are cross-exported from Linux. They are not code-signed, so Windows SmartScreen may warn on first run
("More info" → "Run anyway").

## CI / releases

* **CI** (`.github/workflows/ci.yml`): every pull request into `main` builds the Docker toolchain, runs the self-test
  (a bot plays both levels), exports Windows + Linux and attaches the binaries to the run as an artifact (14 days).
* **CD** (`.github/workflows/release.yml`): pushing a tag `v*` **that points at a commit on `main`** repeats the build
  and publishes a GitHub release with `AnAmazingWorld-<tag>-windows-x86_64.zip`,
  `AnAmazingWorld-<tag>-linux-x86_64.tar.gz` and `SHA256SUMS.txt`. Tags like `v1.0.0-rc1` become pre-releases.
  Tags on other branches are rejected.

```bash
git checkout main && git pull
git tag v1.0.0 && git push origin v1.0.0
```

Both workflows share `.github/workflows/build.yml`; packaging is `tools/package.sh <version>`.

## Layout

* `Dockerfile`, `tools/` — build environment and scripts
* `game/scripts/` — all game code (`player.gd`, `crate.gd`, `levels.gd`, `character_model.gd`, …)
* `game/scripts/dev/selftest.gd` — test bot + screenshot harness
* Everything visual and audible (models, textures, sounds, music) is generated by code — there are no asset files.
* The background music (`game/scripts/music.gd`) is an old-school rock guitar riff: a synthesised plucked-string guitar through
  an overdrive, with bass and drums, 16 bars in E minor at 132 bpm. It is built on a worker thread when the game starts.
  The tests export it to `build/music_riff.wav` so you can listen to it without launching the game. The credits'
  "Happy Birthday" tune is separate (`sfx.gd`) and untouched.
