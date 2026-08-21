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
    if echo "$out" | grep -qE "FAIL|FAILURES|QML ERROR|Cannot |Unable to assign"; then
        failed=1
    fi
}

run_case slots        SlotTest.qml         1200
run_case delegates    DelegateTest.qml     1200
run_case shapes       ShapeHarness.qml     1200
run_case settings     SettingsTest.qml     1500
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
