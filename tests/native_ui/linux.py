"""Drive GTK through real X11 input and inspect its public AT-SPI interfaces."""

from collections import deque
import json
import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import time


def xdotool(*args):
    return subprocess.check_output(["xdotool", *map(str, args)], text=True, timeout=15).strip()


def bus(address, operation, *args):
    output = subprocess.check_output(
        ["busctl", "--json=short", "--timeout=5", f"--address={address}",
         "--", operation, *map(str, args)],
        text=True, stderr=subprocess.PIPE, timeout=10,
    )
    return json.loads(output)["data"]


def wait(description, read, expected, timeout=30):
    deadline = time.monotonic() + timeout
    while True:
        try:
            actual = read()
        except subprocess.CalledProcessError as error:
            # A row may disappear between its table lookup and name read when
            # a query is replaced. Retry against the new table.
            actual = (error.stderr or str(error)).strip()
        if actual == expected:
            return
        if time.monotonic() >= deadline:
            raise AssertionError(f"{description}: expected {expected!r}, last read {actual!r}")
        time.sleep(0.1)


# Values of the AT-SPI Role enumeration are stable across desktop versions.
# Newer ATK releases call the old "push button" role "button".
ROLE_FRAME = 23
ROLE_BUTTON = 43


class Desktop:
    registry = ("org.a11y.atspi.Registry", "/org/a11y/atspi/accessible/root")

    def __init__(self):
        session = os.environ["DBUS_SESSION_BUS_ADDRESS"]
        self.address, = bus(session, "call", "org.a11y.Bus", "/org/a11y/bus",
                            "org.a11y.Bus", "GetAddress")

    def call(self, node, interface, method, *args):
        result, = bus(self.address, "call", *node, "org.a11y.atspi." + interface, method, *args)
        return result

    def prop(self, node, interface, prop):
        return bus(self.address, "get-property", *node, "org.a11y.atspi." + interface, prop)

    def name(self, node):
        return self.prop(node, "Accessible", "Name")

    def children(self, node):
        return self.call(node, "Accessible", "GetChildren")

    def find(self, root, name, interface, role):
        # Avoid walking cells in a table with thousands of search results.
        pending = deque([root])
        while pending:
            node = pending.popleft()
            label = self.name(node)
            if label == name:
                matches_role = role is None or self.call(node, "Accessible", "GetRole") == role
                matches_interface = not interface or "org.a11y.atspi." + interface in self.call(
                    node, "Accessible", "GetInterfaces")
                if matches_role and matches_interface:
                    return node
            if label != "Search results":
                pending.extend(self.children(node))
        return None

    def widget(self, root, name, interface=None, role=None):
        deadline = time.monotonic() + 20
        last_error = None
        while time.monotonic() < deadline:
            try:
                node = self.find(root, name, interface, role)
                if node:
                    return node
            except subprocess.CalledProcessError as error:
                # GTK can destroy a popup or tooltip while we enumerate its children.
                last_error = (error.stderr or str(error)).strip()
            time.sleep(0.1)
        raise AssertionError(f"Could not find accessible widget {name!r} in {root}; "
                             f"last D-Bus error: {last_error}")

    def click(self, node, count=1):
        x, y, w, h = self.call(node, "Component", "GetExtents", "u", 0)
        assert x >= 0 and y >= 0 and w > 0 and h > 0, (node, (x, y, w, h))
        xdotool("mousemove", x + w // 2, y + h // 2, "click", "--repeat", count, "--delay", 80, 1)


class Window:
    def __init__(self):
        window = xdotool("search", "--sync", "--onlyvisible", "--name", "^Drill$").splitlines()[0]
        xdotool("windowactivate", "--sync", window)
        self.desktop = Desktop()
        self.frame = self.desktop.widget(self.desktop.registry, "Drill", role=ROLE_FRAME)
        self.entry = self.desktop.widget(self.frame, "Search", "EditableText")
        self.table = self.desktop.widget(self.frame, "Search results", "Table")

    def query(self, text):
        self.desktop.click(self.entry)
        xdotool("key", "ctrl+a", "BackSpace")
        xdotool("type", "--clearmodifiers", "--", text)

    def row_count(self):
        return self.desktop.prop(self.table, "Table", "NRows")

    def cell(self, row):
        return self.desktop.call(self.table, "Table", "GetAccessibleAt", "ii", row, 0)

    def selected(self):
        return self.desktop.call(self.table, "Table", "GetSelectedRows")

    def entry_text(self):
        return self.desktop.call(self.entry, "Text", "GetText", "ii", 0, -1)

    def cell_name(self, row):
        cell = self.cell(row)
        # The name column packs both an icon and a text renderer. GTK3
        # exposes each renderer as a child of the container cell.
        name = self.desktop.name(cell)
        if name:
            return name
        names = (self.desktop.name(child) for child in self.desktop.children(cell))
        return next((text for text in names if text), "")

    def names(self):
        return [self.cell_name(row) for row in range(self.row_count())]

    def open_result(self, name):
        self.query(name)
        wait("matching packaged row", self.names, [name])
        self.desktop.click(self.cell(0), count=2)


def check_window(root, marker):
    window = Window()
    api = window.desktop
    status = api.widget(window.frame, "Type to search", "Text")
    scope = api.widget(window.frame, "Search in", "Selection")
    first = "drill_native_unique_a.txt"
    second = "drill_native_unique_z.txt"
    files = sorted([first, second, "drill_native_unique.md"])

    # Verify initial focus, incremental queries and a glob in the actual entry.
    xdotool("type", "drill_native_unique")
    wait("initial matches", lambda: sorted(window.names()), files)
    xdotool("type", "--", "*.txt")
    wait("glob matches", lambda: api.name(status), "2 results")
    wait("query text", window.entry_text, "drill_native_unique*.txt")
    wait("glob results", lambda: sorted(window.names()), [first, second])

    header = api.call(window.table, "Table", "GetColumnHeader", "i", 0)
    api.click(header)
    wait("ascending names", window.names, [first, second])
    api.click(window.entry)
    xdotool("key", "Down")
    wait("keyboard selection", window.selected, [0])
    api.click(header)
    wait("descending names", window.names, [second, first])
    wait("selection follows file across sort", window.selected, [1])
    api.click(window.cell(1))
    xdotool("key", "ctrl+c")
    api.click(window.entry)
    xdotool("key", "ctrl+a", "ctrl+v")
    wait("copied path pasted into native entry", window.entry_text, str(root / first))

    # Files and Apps use different sources. Only the registered fixture may
    # be launched by desktop ID. Its Exec writes a marker in this test home.
    window.query("drill_native_unique")
    wait("Files scope", lambda: sorted(window.names()), files)
    api.click(scope)
    xdotool("key", "End", "Return")
    wait("Apps scope", window.names, ["drill_native_unique app"])
    api.click(window.entry)
    xdotool("key", "Down", "Return")
    wait("registered app launch", marker.exists, True)
    api.click(scope)
    xdotool("key", "Home", "Return")
    wait("return to Files", lambda: sorted(window.names()), files)

    api.click(api.widget(window.frame, "Help"))
    api.click(api.widget(window.frame, "Syntax"))
    dialog = api.widget(api.registry, "Search syntax", "Component")
    api.click(api.widget(dialog, "Close"))

    # Use the production page size and controls. Each query must leave the
    # previous scan behind, including one that was stopped at its page limit.
    for index in range(10001):
        (root / f"paged-{index:05}.txt").touch()
    for button, expected_count, expected_status in (
        ("Continue", 10001, "10001 results"),
        ("Stop", 10000, "Stopped · 10000 results"),
    ):
        window.query("paged-*")
        wait("paused search", lambda: api.name(status), "10000 results · More results available",
             timeout=60)
        wait("first page", window.row_count, 10000)
        # The same operation also appears in the Search menu. Select the button
        # by role so a hidden menu item cannot satisfy the test.
        control = api.widget(window.frame, button, role=ROLE_BUTTON)
        if button == "Continue":
            # A fresh walk would find only 10,000 files. The original scan
            # already delivered this row and must retain it when resumed.
            delivered = root / window.cell_name(0)
            delivered.unlink()
        api.click(control)
        wait("search after " + button, lambda: api.name(status), expected_status)
        wait("delivered rows after " + button, window.row_count, expected_count)
        if button == "Continue":
            delivered.touch()
        window.query(first)
        wait("replacement count", window.row_count, 1)
        wait("replacement query", window.names, [first])
    xdotool("key", "Escape")


def test(binary):
    with TemporaryDirectory(prefix="drill-native-") as temp:
        home = Path(temp)
        root = home / "files"
        root.mkdir()
        (root / "drill_native_unique.md").write_text("third")
        (root / "drill_native_unique_a.txt").write_text("first")
        (root / "drill_native_unique_z.txt").write_text("second")
        apps = home / "share/applications"
        apps.mkdir(parents=True)
        marker = home / "launched"
        (apps / "drill-fixture.desktop").write_text(
            "[Desktop Entry]\nType=Application\nName=drill_native_unique app\n"
            f'Exec=/usr/bin/touch "{marker}"\n'
        )
        env = dict(os.environ, XDG_CONFIG_HOME=str(home / "config"),
                   XDG_DATA_HOME=str(apps.parent), LC_ALL="C.UTF-8")
        process = subprocess.Popen([binary, "--root", root], env=env)
        try:
            check_window(root, marker)
            assert process.wait(timeout=10) == 0, "Escape must close the application"
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()


if __name__ == "__main__":
    if sys.argv[1] == "test":
        test(sys.argv[2])
    elif sys.argv[1] == "open":
        Window().open_result(sys.argv[2])
    else:
        raise SystemExit("expected test BINARY or open FILENAME")
