#!/usr/bin/env bash
#
# Optional desktop integration for the Osaka Jade Weather plugin.
#
# The plugin itself works the moment Omarchy loads it -- this script only wires
# up the conveniences that a plugin install cannot do on its own, because they
# live in files that belong to you rather than to the plugin:
#
#   * `osaka-weather` on your PATH (a symlink; the script stays in the plugin)
#   * bash completion for it
#   * SUPER+ALT+R/D/N/W keybindings
#   * a Weather submenu in the Omarchy menu
#
# Everything is opt-in, everything is idempotent, and `--uninstall` removes
# exactly what was added. Run with --dry-run to see what it would do.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/bin/osaka-weather"

BIN_LINK="$HOME/.local/bin/osaka-weather"
COMPLETION="$HOME/.local/share/bash-completion/completions/osaka-weather"
BINDINGS="$HOME/.config/hypr/bindings.lua"
MENU="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
HOOK="$HOME/.config/omarchy/hooks/theme-set.d/osaka-weather.hook"
SHELLJSON="$HOME/.config/omarchy/shell.json"
PLUGIN_ID="io.github.rr-codebase.osaka-jade-weather"
WIDGET_SECTION="${OSAKA_WEATHER_SECTION:-right}"

MARK_BEGIN="-- >>> osaka-jade-weather >>>"
MARK_END="-- <<< osaka-jade-weather <<<"

DRY=0
MODE=install
WANT_HOOK=0
WANT_WIDGET=1
for arg in "$@"; do
  case "$arg" in
  --dry-run) DRY=1 ;;
  --uninstall) MODE=uninstall ;;
  --with-theme-hook) WANT_HOOK=1 ;;
  --no-widget) WANT_WIDGET=0 ;;
  -h | --help)
    cat <<'USAGE'
Optional desktop integration for the Osaka Jade Weather plugin.

The plugin itself works as soon as Omarchy loads it. This wires up the parts a
plugin install cannot, because they live in files that belong to you.

Usage: ./install.sh [--dry-run] [--no-widget] [--with-theme-hook] [--uninstall]

  (default)           PATH symlink, bash completion, keybindings, bar widget
  --no-widget         skip the bar widget
  --with-theme-hook   park the weather when you switch away from its theme
  --dry-run           print the plan, change nothing
  --uninstall         remove exactly what was installed

Environment:
  OSAKA_WEATHER_SECTION   bar section for the widget (default: right)

Menu rows are not added automatically -- they share a file with your own
entries. Paste extras/omarchy-menu.jsonc, markers included.
USAGE
    exit 0
    ;;
  *)
    echo "install.sh: unknown option '$arg'" >&2
    exit 1
    ;;
  esac
done

say() { printf '  %s\n' "$*"; }
run() { (( DRY )) && say "would: $*" || eval "$@"; }

# ---------------------------------------------------------------- install --

install_all() {
  echo "Installing Osaka Jade Weather integration:"

  if [[ -e $BIN_LINK && ! -L $BIN_LINK ]]; then
    say "SKIP  $BIN_LINK exists and is not a symlink -- leaving it alone"
  else
    run "mkdir -p '$(dirname "$BIN_LINK")'"
    run "ln -sfn '$CLI' '$BIN_LINK'"
    say "link  $BIN_LINK -> plugin bin/"
  fi

  if [[ -f $HERE/completions/osaka-weather ]]; then
    run "mkdir -p '$(dirname "$COMPLETION")'"
    run "install -m 0644 '$HERE/completions/osaka-weather' '$COMPLETION'"
    say "shell completion installed"
  fi

  # Keybindings go in a marked block so --uninstall can take them back out
  # without touching anything else in the file.
  if [[ -f $BINDINGS ]] && grep -q "osaka-weather" "$BINDINGS"; then
    say "SKIP  keybindings already present"
  elif [[ -f $BINDINGS ]]; then
    if (( DRY )); then
      say "would: append SUPER+ALT+R/D/N/W bindings to $BINDINGS"
    else
      cat >>"$BINDINGS" <<LUA

$MARK_BEGIN
-- Weather toggles. The moods are independent and stack: rain + night is a
-- storm, rain + day a sun shower.
o.bind("SUPER + ALT + R", "Weather: rain", "osaka-weather rain")
o.bind("SUPER + ALT + D", "Weather: sunshine", "osaka-weather day")
o.bind("SUPER + ALT + N", "Weather: night", "osaka-weather night")
o.bind("SUPER + ALT + W", "Weather: cycle", "osaka-weather cycle")
$MARK_END
LUA
      say "bound SUPER+ALT+R / D / N / W"
    fi
  else
    say "SKIP  $BINDINGS not found"
  fi

  if (( WANT_WIDGET )); then
    add_widget
  else
    say "SKIP  bar widget (--no-widget)"
  fi

  if (( WANT_HOOK )); then
    run "mkdir -p '$(dirname "$HOOK")'"
    run "install -m 0755 '$HERE/extras/theme-set-hook.sh' '$HOOK'"
    say "theme hook installed (weather parks itself outside its theme)"
  elif [[ -f $HOOK ]]; then
    say "SKIP  theme hook already installed"
  else
    say "NOTE  theme hook not installed; pass --with-theme-hook to add it"
  fi

  if [[ -f $MENU ]] && grep -q '"osaka-weather.rain"' "$MENU"; then
    say "SKIP  menu entries already present"
  else
    say "NOTE  menu rows not added automatically (they share a file with your"
    say "      own entries). Paste extras/omarchy-menu.jsonc into"
    say "      ~/.config/omarchy/extensions/omarchy-menu.jsonc"
  fi

  (( DRY )) || {
    command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
  }
  echo
  echo "Done. Try:  osaka-weather --help"
}

# ----------------------------------------------------------- bar widget --

widget_present() {
  [[ -f $SHELLJSON ]] && jq -e --arg id "$PLUGIN_ID" \
    '[.bar.layout[]?[]?.id] | index($id) != null' "$SHELLJSON" >/dev/null 2>&1
}

add_widget() {
  [[ -f $SHELLJSON ]] || { say "SKIP  $SHELLJSON not found"; return 0; }
  if widget_present; then say "SKIP  bar widget already placed"; return 0; fi
  if (( DRY )); then say "would: add the bar widget to the '$WIDGET_SECTION' section"; return 0; fi

  cp -- "$SHELLJSON" "$SHELLJSON.osaka-bak"
  if jq --arg id "$PLUGIN_ID" --arg sec "$WIDGET_SECTION" \
      '.bar.layout[$sec] = ([{id: $id}] + (.bar.layout[$sec] // []))' \
      "$SHELLJSON.osaka-bak" >"$SHELLJSON.tmp" && jq -e . "$SHELLJSON.tmp" >/dev/null; then
    mv -f -- "$SHELLJSON.tmp" "$SHELLJSON"
    rm -f -- "$SHELLJSON.osaka-bak"
    say "bar widget added to the '$WIDGET_SECTION' section"
  else
    rm -f -- "$SHELLJSON.tmp"
    mv -f -- "$SHELLJSON.osaka-bak" "$SHELLJSON"
    say "bar widget NOT added (edit would have broken $SHELLJSON)"
  fi
}

remove_widget() {
  [[ -f $SHELLJSON ]] || return 0
  widget_present || return 0
  if (( DRY )); then say "would: remove the bar widget from $SHELLJSON"; return 0; fi

  cp -- "$SHELLJSON" "$SHELLJSON.osaka-bak"
  if jq --arg id "$PLUGIN_ID" \
      '.bar.layout |= with_entries(.value |= map(select(.id != $id)))' \
      "$SHELLJSON.osaka-bak" >"$SHELLJSON.tmp" && jq -e . "$SHELLJSON.tmp" >/dev/null; then
    mv -f -- "$SHELLJSON.tmp" "$SHELLJSON"
    rm -f -- "$SHELLJSON.osaka-bak"
    say "removed bar widget"
  else
    rm -f -- "$SHELLJSON.tmp"
    mv -f -- "$SHELLJSON.osaka-bak" "$SHELLJSON"
    say "bar widget left in place (edit would have broken $SHELLJSON)"
  fi
}

# ------------------------------------------------------------- menu rows --

remove_menu_rows() {
  [[ -f $MENU ]] || return 0
  if ! grep -q "osaka-jade-weather >>>" "$MENU"; then
    if grep -q '"osaka-weather' "$MENU"; then
      say "ACTION NEEDED  menu rows present but without the marker comments, so"
      say "               they cannot be removed safely. Delete the keys starting"
      say "               \"osaka-weather\" from $MENU"
    fi
    return 0
  fi

  if (( DRY )); then
    say "would: remove the marked menu rows from $MENU"
    return 0
  fi

  cp -- "$MENU" "$MENU.osaka-bak"
  python3 - "$MENU" <<'PYEOF' || { mv -f -- "$MENU.osaka-bak" "$MENU"; say "menu rows left alone (removal would have broken the file)"; return 0; }
import json, pathlib, re, sys
p = pathlib.Path(sys.argv[1])
lines = p.read_text().splitlines(keepends=True)
begin = next(i for i, l in enumerate(lines) if "osaka-jade-weather >>>" in l)
end = next(i for i, l in enumerate(lines) if "osaka-jade-weather <<<" in l)
text = "".join(lines[:begin] + lines[end + 1:])
# A trailing comma before the closing brace is invalid once our block is gone.
text = re.sub(r",(\s*)\n(\s*(?://[^\n]*\n\s*)*)\}", r"\1\n\2}", text, count=1)
json.loads(re.sub(r"^\s*//.*$", "", text, flags=re.M))
p.write_text(text)
PYEOF
  rm -f -- "$MENU.osaka-bak"
  say "removed menu rows"
}

# -------------------------------------------------------------- uninstall --

uninstall_all() {
  echo "Removing Osaka Jade Weather integration:"

  if [[ -L $BIN_LINK ]] && [[ "$(readlink -f "$BIN_LINK")" == "$(readlink -f "$CLI")" ]]; then
    run "rm -f '$BIN_LINK'"
    say "removed $BIN_LINK"
  else
    say "SKIP  $BIN_LINK is not our symlink"
  fi

  [[ -f $COMPLETION ]] && { run "rm -f '$COMPLETION'"; say "removed completion"; }

  if [[ -f $BINDINGS ]] && grep -qF -- "$MARK_BEGIN" "$BINDINGS"; then
    if (( DRY )); then
      say "would: strip the marked block from $BINDINGS"
    else
      # Delete strictly between the markers, inclusive.
      sed -i "/$(printf '%s' "$MARK_BEGIN" | sed 's/[]\/$*.^[]/\\&/g')/,/$(printf '%s' "$MARK_END" | sed 's/[]\/$*.^[]/\\&/g')/d" "$BINDINGS"
      say "removed keybindings"
    fi
  fi

  if [[ -f $HOOK ]]; then
    run "rm -f '$HOOK'"
    say "removed theme hook"
  fi

  remove_widget
  remove_menu_rows

  echo
  echo "The plugin itself is untouched. Remove it with:"
  echo "  omarchy plugin enable omarchy.background"
  echo "  omarchy plugin remove io.github.rr-codebase.osaka-jade-weather"
}

case "$MODE" in
install) install_all ;;
uninstall) uninstall_all ;;
esac
