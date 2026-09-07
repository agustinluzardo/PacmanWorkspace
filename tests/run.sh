#!/usr/bin/env bash
# Runs the Pac-Man Workspaces test suite offscreen, against mocked Quickshell and
# DankMaterialShell modules. No compositor, no DMS install and no GPU required.
#
#   ./tests/run.sh
#
# Needs Qt 6 with the QML tooling. On Debian/Ubuntu:
#   apt-get install qt6-base-dev qt6-declarative-dev qt6-declarative-dev-tools \
#                   qml6-module-qtquick qml6-module-qtquick-shapes \
#                   qml6-module-qtqml-workerscript qml6-module-qtquick-window
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(dirname "$here")"
mock="$here/mock"
# Works both when the plugin lives in a PacmanWorkspaces/ subdirectory and when
# it sits at the repo root (standalone plugin repo, cloned straight into
# ~/.config/DankMaterialShell/plugins/).
if [ -f "$repo/PacmanWorkspaces/plugin.json" ]; then
    plugin="$repo/PacmanWorkspaces"
elif [ -f "$repo/plugin.json" ]; then
    plugin="$repo"
else
    echo "!! could not find plugin.json next to the tests"
    exit 1
fi
build="$here/.build"
mkdir -p "$build"

qtbin=""
for c in /usr/lib/qt6/bin /usr/lib/x86_64-linux-gnu/qt6/bin /usr/bin; do
    [ -x "$c/qmllint" ] && qtbin="$c" && break
done

# ---------------------------------------------------------------- build ------
if [ ! -x "$build/render" ] || [ "$here/render.cpp" -nt "$build/render" ]; then
    echo "==> building offscreen renderer"
    g++ -fPIC -O1 -o "$build/render" "$here/render.cpp" \
        $(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Gui Qt6Core) || {
        echo "!! could not build the renderer - is qt6-base-dev / qt6-declarative-dev installed?"
        exit 1
    }
fi

# The real widget asks for Shape.CurveRenderer, which only exists in Qt >= 6.6.
# Strip it for the local run so the suite also works on older Qt; it changes how
# the shapes are rasterised, never their geometry or any of the logic under test.
sed '/preferredRendererType: Shape.CurveRenderer/d' \
    "$plugin/PacmanWorkspaces.qml" > "$mock/PacmanWorkspacesUT.qml"
cp "$plugin/PacmanWorkspacesSettings.qml" "$mock/PacmanWorkspacesSettingsUT.qml"

export QT_QPA_PLATFORM=offscreen
export QT_QUICK_BACKEND=software
export QML2_IMPORT_PATH="$mock"

failed=0

run_case() {
    local name="$1" file="$2" delay="${3:-1500}"
    echo
    echo "==> $name"
    local out
    out="$(cd "$mock" && "$build/render" "$file" "$build/${name}.png" "$delay" 2>&1 | grep -v XDG_RUNTIME_DIR)"
    echo "$out" | sed 's/^qml: //'
    if echo "$out" | grep -qE "FAIL|FAILURES|QML ERROR|Cannot |Unable to assign|ReferenceError|TypeError"; then
        failed=1
    fi
    # A suite producing NO checks at all passes this runner without saying a
    # word, and that has happened: a broken reader left the strip readback blank
    # and the run still came out green. A floor per suite makes it visible.
    local n
    n="$(echo "$out" | grep -cE '^(qml: )?(PASS|FAIL) ')"
    echo "   $n checks"
    if [ "$n" -lt "${4:-5}" ]; then
        echo "   !! FAIL $name produced $n checks (floor ${4:-5}) - the suite is exercising nothing"
        failed=1
    fi
}

run_case slots        SlotTest.qml         1200
run_case delegates    DelegateTest.qml     1200
run_case shapes       ShapeHarness.qml     1200 0
# ShapeHarness renders a reference image and asserted nothing: a drawing that
# came out blank passed just the same. Its pixels are counted now - which is
# exactly the check that was missing everywhere.
echo "   -- pixels in the shapes render"
python3 "$here/pixels.py" "$build/shapes.png" --pacman | sed 's/^/   /' || failed=1
run_case scroll       ScrollTest.qml       1200
run_case background   BackgroundTest.qml   1200
run_case mouth        MouthRender.qml      1200 0
# The mouth pellet is a handful of pixels: a property saying "on" proves
# nothing about whether it reached the screen. The two halves of this render
# differ ONLY by that setting, so the pixel counts have to differ too.
echo "   -- with vs without the mouth pellet"
python3 "$here/pixels.py" "$build/mouth.png" | sed 's/^/   /' || failed=1
run_case colormode    ColorModeTest.qml    1200
run_case settings     SettingsTest.qml     1500 2

# The page reports the keys it actually built; the source says which ones it
# should have. Only comparing the two catches a control that silently failed to
# construct - a count baked into the test just rots with every new setting.
echo "   -- settings: page built vs source declared"
built="$(cd "$mock" && "$build/render" SettingsTest.qml "$build/settings.png" 1500 2>&1 \
    | sed -n 's/^qml: SETTING_KEYS //p' | tr ',' '\n' | sort -u)"
declared="$(grep -o 'settingKey: "[A-Za-z0-9_]*"' "$repo/PacmanWorkspacesSettings.qml" \
    | sed 's/.*"\(.*\)"/\1/' | sort -u)"
missing="$(comm -13 <(echo "$built") <(echo "$declared"))"
extra="$(comm -23 <(echo "$built") <(echo "$declared"))"
if [ -n "$missing" ]; then echo "   !! FAIL declared but never built: $missing"; failed=1; fi
if [ -n "$extra" ];   then echo "   !! FAIL built but not declared: $extra"; failed=1; fi
[ -z "$missing$extra" ] && echo "   ok $(echo "$declared" | wc -l) settings, page matches source"
run_case integration  IntegrationTest.qml  6000
run_case frightened   FrightenedTest.qml   15000

# ----------------------------------------------------------------- lint ------
if [ -n "$qtbin" ]; then
    echo
    echo "==> qmllint"
    # Unqualified `root`/`cell` access inside the delegate Component is expected:
    # ComponentBehavior: Bound cannot be used here (DMS instantiates the bar pills
    # from a Loader in another file), so those ids resolve through the component's
    # creation context at runtime. Qt.callLater is a known qmllint false positive.
    for f in PacmanWorkspacesUT.qml PacmanWorkspacesSettingsUT.qml; do
        noise="$("$qtbin/qmllint" -I "$mock" "$mock/$f" 2>&1 \
            | grep "^Warning:" \
            | grep -vE "Unqualified access|callLater" || true)"
        if [ -n "$noise" ]; then
            echo "!! unexpected qmllint warnings in $f:"
            echo "$noise"
            failed=1
        else
            echo "   $f: clean (only the expected unqualified-access notes)"
        fi
    done
fi

echo
if [ "$failed" -eq 0 ]; then
    echo "=== ALL SUITES PASS ==="
else
    echo "=== FAILURES - see above ==="
fi
exit "$failed"
