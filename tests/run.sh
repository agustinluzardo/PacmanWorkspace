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
        $(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Gui Qt6Core Qt6Test) || {
        echo "!! could not build the renderer - is qt6-base-dev / qt6-declarative-dev installed?"
        exit 1
    }
fi

# Shape.preferredRendererType only exists on Qt >= 6.6, so on older Qt it has to come
# out or the file will not load. That is not free: a whole class of bug lives
# only in that renderer - a ghost keeping its old colour when its fill changed
# but its geometry did not - so a suite that always strips it cannot see them.
# Keep it wherever the Qt in use supports it, and say which path ran.
qtver="$(pkg-config --modversion Qt6Quick 2>/dev/null || echo 0)"
qtmajor="${qtver%%.*}"
qtminor="$(echo "$qtver" | cut -d. -f2)"
if [ "${qtmajor:-0}" -gt 6 ] || { [ "${qtmajor:-0}" -eq 6 ] && [ "${qtminor:-0}" -ge 6 ]; }; then
    cp "$plugin/PacmanWorkspaces.qml" "$mock/PacmanWorkspacesUT.qml"
    echo "==> Qt $qtver: testing against the real Shape renderers"
else
    # The whole property is Qt 6.6+, not just the CurveRenderer value.
    sed '/preferredRendererType:/d' \
        "$plugin/PacmanWorkspaces.qml" > "$mock/PacmanWorkspacesUT.qml"
    echo "==> Qt $qtver: too old for Shape.CurveRenderer, stripped for this run"
    echo "    (CurveRenderer-only rendering bugs cannot be caught here)"
fi
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
    if echo "$out" | grep -qE "FAIL|FAILURES|QML ERROR|Cannot |Unable to assign"; then
        failed=1
    fi
}

run_case slots        SlotTest.qml         1200
run_case delegates    DelegateTest.qml     1200
run_case shapes       ShapeHarness.qml     1200
run_case scroll       ScrollTest.qml       1200
run_case settings     SettingsTest.qml     1500
run_case integration  IntegrationTest.qml  6000
run_case frightened   FrightenedTest.qml   15000

# ------------------------------------------------------------- repaint -------
# The only checks that look at pixels. Everything else passes while the screen
# still shows the old colour, which is the exact shape of the bug being guarded:
# the ghost under the pointer keeping its own colour when frightened mode
# arrives. The pointer is parked on slot 0 for real, because the offscreen
# pointer sits at 0,0 by default and would otherwise hover it by accident.
echo
echo "==> repaint"
probe() {   # probe <grabMs> <hoverSpec>
    ( cd "$mock" && PROBE="10,16;31,16" HOVER="$2" "$build/render" RepaintTest.qml \
        "$build/repaint-$1.png" "$1" 2>&1 ) | grep "^PIXEL" | awk '{print $NF}' | tr '\n' ' '
}
dominant_red() { [ "$((16#${1:1:2}))" -gt "$((16#${1:5:2}))" ]; }
dominant_blue() { [ "$((16#${1:5:2}))" -gt "$((16#${1:1:2}))" ]; }

check_pair() {   # check_pair <label> <hoverSpec>
    local label="$1" hov="$2"
    local before after b0 a0 a1
    before="$(probe 300 "$hov")"
    after="$(probe 900 "$hov")"
    b0="${before%% *}"
    a0="${after%% *}"
    a1="$(echo "$after" | awk '{print $2}')"
    echo "   $label: slot0 $b0 -> $a0   (slot1 $a1)"
    if dominant_red "$b0" && dominant_blue "$a0" && dominant_blue "$a1"; then
        echo "      both ghosts turn frightened blue"
    else
        echo "!! FAIL $label: expected slot0 red then blue, and slot1 blue"
        failed=1
    fi
}

check_pair "pointer away  " "200,50@300"
check_pair "pointer on slot 0" "10,10@300"

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
