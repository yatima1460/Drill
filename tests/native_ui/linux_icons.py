"""Verify GtkTreeView's visible icon pixels when embedded formats are toggled."""

from pathlib import Path
import shlex
import shutil
import subprocess


GREEN = bytes((0, 255, 0))
SIDE = 32
EMBEDDED = GREEN * SIDE ** 2


def check_icons(window, root, wait, xdotool):
    source = Path(__file__).resolve()
    tools = source.parents[2] / "tools"
    helper = root.parent / "read-pixels"
    sdk = subprocess.check_output(["pkg-config", "--cflags", "--libs", "gdk-3.0"], text=True)
    subprocess.run(["cc", "-Wall", "-Werror", str(source.with_name("linux_pixels.c")),
                    "-o", helper, *shlex.split(sdk)], check=True)

    pe = "icon-pe32.exe"
    linked = "linked-png.aPpImAgE"
    svg = "direct-svg.AppImage"
    iso = "rock-ridge.AppImage"
    bad_app = "cyclic.aPpImAgE"
    bad_pe = "no-icon.exe"
    bundle_fixtures = source.parent / "fixtures/mac-bundles"
    for name in ("Jade.app", "Carmine.app", "Missing.app"):
        shutil.copytree(bundle_fixtures / name, root / name)
    (root / "ordinary-folder").mkdir()
    app_fixtures = tools / "appimage-icon-wasm/tests/fixtures"
    shutil.copyfile(tools / "exe-icon-wasm/tests/fixtures" / pe, root / pe)
    for name in (linked, svg, iso, bad_app):
        shutil.copyfile(app_fixtures / Path(name).with_suffix(".AppImage"), root / name)
    (root / bad_pe).write_bytes(b"fixture without an icon")
    api = window.desktop

    def query(name):
        window.query(name)
        wait("icon row " + name, window.names, [name])
        # Keep the pointer off the row so GTK's hover state cannot change it.
        xdotool("mousemove", 0, 0)

    def read(x, y, width, height):
        return subprocess.check_output([helper, *map(str, (x, y, width, height))], timeout=5)

    def find_icon():
        # The table's left edge includes the icon column. The accessible cell
        # bounds supply its row's vertical position in actual screen coordinates.
        x, _, _, _ = api.call(window.table, "Component", "GetExtents", "u", 0)
        _, y, _, height = api.call(window.cell(0), "Component", "GetExtents", "u", 0)
        width = 72
        rgb = read(x, y, width, height)
        green = [(i % width, i // width) for i in range(width * height)
                 if rgb[i * 3:i * 3 + 3] == GREEN]
        if len(green) == SIDE ** 2:
            xs, ys = zip(*green)
            if max(xs) - min(xs) == max(ys) - min(ys) == SIDE - 1:
                return (x + min(xs), y + min(ys))
        return None

    query(pe)
    # Establish the icon bounds from its actual decoded colors, never from a
    # theme-specific padding constant. Subsequent queries all use the first row.
    wait("32x32 PE icon", lambda: find_icon() is not None, True)
    x, y = find_icon()

    def pixels():
        return read(x, y, SIDE, SIDE)

    def rendered(name, expected):
        query(name)
        wait("rendered icon " + name, lambda: pixels() == expected, True)

    def fallback(name):
        query(name)
        # A file-type icon has a visible glyph in this theme. A blank cell or
        # leftover opaque green fixture cannot satisfy this check.
        def has_glyph():
            rgb = pixels()
            return len({rgb[i:i+3] for i in range(0, len(rgb), 3)}) > 2 and GREEN * SIDE not in rgb
        wait("visible fallback " + name, has_glyph, True)
        return pixels()

    def toggle(label):
        xdotool("key", "ctrl+comma")
        panel = api.widget(api.registry, "Interface", "Component")
        api.click(api.widget(panel, label))
        api.click(api.widget(panel, "Close"))
        xdotool("mousemove", 0, 0)

    for app in (linked, svg, iso):
        rendered(app, EMBEDDED)
    app_fallback = fallback(bad_app)
    rendered(pe, EMBEDDED)
    exe_fallback = fallback(bad_pe)
    rendered(linked, EMBEDDED)
    toggle("Show AppImage icons")
    # Check the same visible row without reissuing the query so cached artwork
    # has to be invalidated when the setting changes.
    wait("invalidate displayed AppImage", lambda: pixels() == app_fallback, True)
    rendered(pe, EMBEDDED)
    toggle("Show EXE icons")
    wait("invalidate displayed EXE", lambda: pixels() == exe_fallback, True)
    # Bundle icons stay enabled with both executable formats switched off.
    rendered("Carmine.app", bytes((255, 0, 0)) * SIDE ** 2)
    folder_icon = fallback("ordinary-folder")
    rendered("Jade.app", EMBEDDED)
    assert fallback("Missing.app") != folder_icon, "Missing artwork should use an application icon"
    toggle("Show AppImage icons")
    rendered(linked, EMBEDDED)
    rendered(pe, exe_fallback)
    toggle("Show EXE icons")
    wait("restore displayed EXE", lambda: pixels() == EMBEDDED, True)
