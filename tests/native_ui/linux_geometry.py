"""Exercise GTK window geometry across application restarts under Openbox."""

from contextlib import contextmanager
from pathlib import Path
import subprocess


def check_geometry(binary, root, env, xdotool, wait):
    config = Path(env["XDG_CONFIG_HOME"]) / "drill" / "window.ini"
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text("[Window]\nwidth=-7\nheight=0\nmaximized=true\n")

    @contextmanager
    def running():
        # Openbox supplies the titlebar for the double-click below.
        process = subprocess.Popen([binary, "--root", root], env=dict(env, GTK_CSD="0"))
        try:
            window = xdotool("search", "--all", "--sync", "--onlyvisible", "--pid", process.pid,
                             "--name", "^Drill$").splitlines()[0]
            xdotool("windowactivate", "--sync", window)
            yield window
            xdotool("key", "Escape")
            assert process.wait(timeout=10) == 0
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()

    def size(window):
        fields = dict(line.split("=", 1) for line in
                      xdotool("getwindowgeometry", "--shell", window).splitlines())
        return int(fields["WIDTH"]), int(fields["HEIGHT"])

    def toggle_maximized(window):
        xdotool("mousemove", "--window", window, 100, 1, "mousemove_relative", "--", 0, -9,
                "click", "--repeat", 2, "--delay", 80, 1)

    with running() as window:
        # An invalid saved size should leave the normal first-launch dimensions intact.
        wait("fresh window", lambda: size(window), (680, 470))
        normal = (725, 505)
        xdotool("windowsize", "--sync", window, *normal)
        wait("resized window", lambda: size(window), normal)

    with running() as window:
        wait("restored normal size", lambda: size(window), normal)
        toggle_maximized(window)
        wait("maximized window", lambda: all(actual > original for actual, original in
                                              zip(size(window), normal)), True)
        maximized = size(window)

    with running() as window:
        wait("restored maximized state", lambda: size(window), maximized)
        toggle_maximized(window)
        wait("normal bounds after unmaximizing", lambda: size(window), normal)
