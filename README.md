# Osaka Jade Weather

Live weather for your Omarchy wallpaper. Rain, sunshine and night are three
**independent toggles that stack** — rain over night is a storm, rain over
daylight is a sun shower.

![Night, and night with rain](preview.png)

Everything is real-time QML drawn straight onto the background layer. No video,
no animated GIF, no second wallpaper daemon. With all three toggles off it is a
still photograph with a very slow drift, and costs essentially nothing.

## Read this first: it replaces your background renderer

This plugin declares `clonedFrom: omarchy.background`, which means Omarchy
**disables its own background plugin and uses this one instead** while it is
enabled. That is not incidental — the day/night colour grade is applied to the
photograph itself, so the plugin has to own the layer the photo is drawn on. An
overlay-only version could draw rain, but could never turn night into morning.

Going back is one command, and your wallpaper settings are untouched:

```bash
omarchy plugin enable omarchy.background
```

## Install

```bash
omarchy plugin add https://github.com/RR-CodeBase/omarchy-osaka-jade-weather.git --enable
```

That is the whole install — the weather layer is live as soon as the shell
picks it up. (`plugin add` is for first installs only; it refuses an id that is
already present and points you at `plugin update`.)

Prefer to read the code first? Clone it yourself; Omarchy loads any valid
plugin directory:

```bash
git clone https://github.com/RR-CodeBase/omarchy-osaka-jade-weather.git \
  ~/.config/omarchy/plugins/io.github.rr-codebase.osaka-jade-weather
omarchy plugin enable io.github.rr-codebase.osaka-jade-weather
```

The directory name **must** match the `id` in `manifest.json` — that is where
`omarchy plugin update` and `omarchy plugin remove` look, and they will not
find the plugin otherwise. `omarchy plugin add` names it that way for you.

### Optional extras

`osaka-weather` on your PATH, shell completion and `SUPER+ALT` keybindings live
in files that belong to you, so a plugin install cannot write them:

```bash
cd ~/.config/omarchy/plugins/io.github.rr-codebase.osaka-jade-weather
./install.sh --dry-run    # see exactly what it would touch
./install.sh              # idempotent; safe to re-run
```

Add `--with-theme-hook` to also install `extras/theme-set-hook.sh`, which parks
the weather when you switch to another theme and restores your mood when you
come back. It exists because the sky placement is tuned per wallpaper — weather
composed for one photograph looks wrong on another. Off by default; the theme
it watches is a variable at the top of the file.

It skips anything already present and never edits a file it did not create a
marked block in. `./install.sh --uninstall` removes precisely what it added.

Without it the plugin still works — drive it with the full path,
`~/.config/omarchy/plugins/io.github.rr-codebase.osaka-jade-weather/bin/osaka-weather`,
or with the optional bar widget below.

### Updating

```bash
omarchy plugin update io.github.rr-codebase.osaka-jade-weather
```

Your state file is not touched by an update — moods, dials and sky placement
survive.

### Uninstall

Run these **in order** — `install.sh` lives inside the plugin, so removing the
plugin first would take the uninstaller with it:

```bash
cd ~/.config/omarchy/plugins/io.github.rr-codebase.osaka-jade-weather
./install.sh --uninstall                   # PATH link, completions, keybindings, hook
omarchy plugin enable omarchy.background   # hand the wallpaper back to Omarchy
cd ~ && omarchy plugin remove io.github.rr-codebase.osaka-jade-weather
```

That removes the menu rows too, provided you pasted them with their marker
comments. It deletes the marked line range rather than rewriting the file, so
your own entries and comments survive, and it restores a backup if the result
would not parse. Rows pasted without the markers are reported, not guessed at.

**State is kept.** `~/.local/state/omarchy/weather-fx.json` survives, so a
reinstall picks up your moods, dials and sky placement. Delete it for a clean
slate.

Note that `omarchy plugin remove` deletes the plugin directory — including its
git checkout if you cloned it. Nothing is lost that is not on GitHub, and
reinstalling with `omarchy plugin add` gives you a fresh clone with `origin`
already set.

## The three toggles

| | |
|---|---|
| 󰖗 `rain` | two rain curtains at different depths, thickened mist, ground splashes, distant lightning, a wet desaturated grade |
| 󰖙 `day` | warm grade, sun disc, seven swaying god rays, drifting dust motes |
| 󰖔 `night` | cool grade, moon, ninety twinkling stars, fireflies over the rooftops |

Combinations are real states, not collisions. The colour grade **averages** the
active moods rather than summing them, so `rain + day` lands on "overcast
afternoon" instead of blowing out:

```
rain + night  → Night Storm      day + night  → Golden Hour
rain + day    → Sun Shower       all three    → Everything At Once
```

## Control

```bash
osaka-weather                 # what's on
osaka-weather rain            # toggle
osaka-weather night on        # set explicitly
osaka-weather storm           # preset
osaka-weather cycle           # step through the good combinations
osaka-weather auto            # day or night from the local sunrise/sunset
osaka-weather sync            # match the real weather outside (wttr.in)
osaka-weather --help
```

Keybindings, if you ran `install.sh`:

```
SUPER+ALT+R  rain      SUPER+ALT+D  sunshine
SUPER+ALT+N  night     SUPER+ALT+W  cycle
```

There is also an optional **bar widget** — the icon shows the current mood,
click cycles, right-click toggles rain, scroll changes intensity. Because this
plugin registers as a service as well as a widget, `omarchy plugin enable`
claims the service slot and will not place the widget for you. Add it by hand
to `~/.config/omarchy/shell.json`, in whichever section you want:

```jsonc
"right": [ { "id": "io.github.rr-codebase.osaka-jade-weather" }, ... ]
```

## Omarchy menu

`extras/omarchy-menu.jsonc` holds a ready-made **Osaka Jade Weather** submenu —
the three toggles with live tick marks, the presets, and the two automatic
modes. Paste its contents into your own
`~/.config/omarchy/extensions/omarchy-menu.jsonc`, inside the top-level object;
the file hot-reloads on save.

**Keep the two marker comments.** `install.sh --uninstall` uses them to take
exactly these rows back out later without disturbing anything else in that
file.

The ids are namespaced (`osaka-weather.*`) so they never collide with Omarchy's
own weather forecast rows, and each toggle's `checked` condition reads the live
state file rather than caching, so the ticks are always accurate.

## Tuning it to your wallpaper

The defaults are composed for the Osaka Jade *Glowing City* background: the moon
sits in the one gap of open sky, the stars stop at the ridge line, the mist
bands lie on the city. On a different photograph the moon may well end up inside
a building. Every placement value is a fraction of the screen, and adjustable:

```bash
osaka-weather sky                      # show current placement
osaka-weather sky moon 0.60 0.11 0.52  # x, y, diameter
osaka-weather sky sun  0.60 0.14 0.95
osaka-weather sky horizon 0.34         # where the sky ends; stars stop here
osaka-weather sky skyLeft 0.16         # stars fade in past foreground objects
osaka-weather sky groundLevel 0.42     # top of the near foreground
osaka-weather sky reset
```

Other dials: `intensity` (0.2–2.0, particle density), `wind` (−1–1, rain slant),
and the booleans `drift` (slow ken-burns push), `parallax` (photo leans away
from the pointer), `grain` (film grain) and `enabled` (master switch).

## How it fits together

```
~/.local/state/omarchy/weather-fx.json   state, the single source of truth
bin/osaka-weather                        the only writer
WeatherState.qml                         watches that file; one instance
WeatherFx.qml                            the visuals; one per monitor
Background.qml                           photo transform + colour grade
WeatherWidget.qml                        optional bar widget
assets/generate.py                       regenerates every sprite
```

`osaka-weather` writes the state file atomically and then pokes
`omarchy-shell -q weather-fx reload`. The IPC only skips the file watcher's
latency — hand-editing the JSON, or driving it over SSH, works just as well.

Sprites are generated, not downloaded: `python3 assets/generate.py` rebuilds
every one from stdlib Python. They are white with a meaningful alpha channel and
get tinted in QML, so one small atlas serves rain, sun, moon, stars and
fireflies.

## Notes for the curious

* A **NaN animation target segfaults Quickshell** inside the scene graph with no
  QML warning at all. If you fork this and the shell starts crash-looping, look
  for an animation whose `to:` evaluates to `undefined`.
* `ImageParticle` stretches its texture to a **square** quad — which is why
  `raindrop.png` is a thin streak drawn inside a 128×128 canvas rather than a
  128×10 image.
* Stopping a `ParticleSystem` **freezes its last frame** rather than clearing it,
  so each system keeps running for one particle lifetime after its mood is
  switched off, and fades out underneath.

## Requirements

Omarchy 4.x (Quattro) with its Quickshell-based shell, plus `jq`. `curl` is only
needed for `osaka-weather sync`. Qt's `QtQuick.Particles`, `QtQuick.Effects` and
`QtQuick.Shapes` modules ship with `qt6-declarative`.

## Licence

MIT — see [LICENSE](LICENSE).

`Background.qml` is a derivative of Omarchy's own `omarchy.background` plugin,
also MIT. [NOTICE](NOTICE) records exactly which parts come from Omarchy and
which were added here.
