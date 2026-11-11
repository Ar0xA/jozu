# Jōzu 上手

A puzzle RPG of single brush strokes, set among the yokai of Heian-era Japan.

The look comes from real Japanese painting: Hasegawa Tōhaku's *Pine Trees* behind the title,
Sesshū's Long Scroll unrolling above the road map, and the Muromachi *Hyakki Yagyō Emaki*
(the Night Parade scroll the story is about) behind the dialogue. All are public domain
(see `art/CREDITS.md`). Text is set in Yuji Syuku, a brush-written typeface (SIL OFL, `fonts/OFL.txt`).
The pieces on the board are figures lifted from old paintings too: Tomoe Gozen as Suzu, Ōtsu-e and
Kyōsai oni, Sōjōbō the tengu, the fox and ghost of the *Bakemono no e* scroll, Hokusai's nine-tailed fox
and Sekien's lantern ghost. The board and UI are brushed in code and passed through a paint shader that adds ink bleed,
dry-brush breakup and paper grain.

Open the folder in **Godot 4.3+** (built and tested on 4.7.2) and press Play, or run:

    godot --path .

Music: a 1920s shakuhachi recording of *Shika no Tōne* under the story, *Sakura Sakura* on synthesised
koto for the title and road, and original koto, shamisen and taiko pieces in the miyako-bushi scale for
the stages. Press `M` to mute.

One hundred stations in ten chapters. The story stages are hand-made; the rest are produced by a
generator (`tools/gen`, C#) that builds candidate boards for each chapter, solves them exactly and keeps
a rising run of them. `tools/verify.gd` then replays every stored solution through the real rules, so
each station is proven masterable at base stats.

## How it plays

Each turn you paint **one stroke**: up to four tiles of steps and cuts, never crossing your own ink.
Then every yokai answers, exactly as the red wash on the board predicted. Nothing is random.

- **Momentum 勢** — each straight step before a cut adds 1 damage (1 / 2 / 3). Distance is your weapon.
- **Later chapters** add ice (you slide until stopped, gathering momentum), fire (burns if you rest on it),
  umbrella yokai that hop two tiles, kappa that hunt from the water, wall yokai that must be broken,
  and a skeleton that strikes all eight tiles around it.
- **Red tiles** — where you would be struck if you sheathed the brush there.
- **Waza** learned on the road: 縮地 leap over a tile, 結界 paste a ward, 喝 shout yokai away (into water, they are gone).
- **上手 seal** — clear a station unharmed within the mastery stroke count. Always possible with no upgrades.
- **Training 修練** — points from stations buy ink, ki and extra waza uses. Help for the road, never required.

Controls: click / drag / arrow keys to paint, `Space` sheathe, `Z` or right-click undo, `R` restart, `1 2 3` waza.

## Files

- `scripts/sim.gd` — the rules, pure and deterministic
- `scripts/data.gd` — the hundred stations, story and text (generated file; edit the sources in `tools/`)
- `scripts/ink.gd` — brushwork drawn in code
- `shaders/paint.gdshader` — ink bleed, dry brush and paper grain over the whole frame
- `art/`, `fonts/` — public-domain paintings and the bundled typeface
- `tools/make_audio.py` — regenerates the synthesised music and sound effects (needs numpy)
- `tools/gen/` — level generator and exact solver; `tools/build_levels.py` assembles `scripts/data.gd` from
  `tools/story_stages.json` (hand-written stages) and `tools/generated.json`
- `tools/verify.gd` — replays every stage's stored solution: `godot --headless --path . -s tools/verify.gd`
- `tools/solve.gd` — headless checker that proves each station solvable: `godot --headless --path . -s tools/solve.gd`
