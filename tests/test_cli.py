import os
import sys
import threading
import time
import uuid
from pathlib import Path

import pytest

src_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src"))
sys.path.insert(0, src_path)

import cli


def test_main_requires_query(monkeypatch, capsys):
    monkeypatch.setattr(cli.sys, "argv", ["cli.py"])
    app = cli.CLI()

    with pytest.raises(SystemExit) as exc_info:
        app.main()

    out = capsys.readouterr().out
    assert "Error: Please provide a search query as an argument." in out
    assert "Usage: python cli.py <search_query>" in out
    assert exc_info.value.code == 1


def test_main_prints_results_headless(monkeypatch, capsys):
    class FakeSearch:
        last_instance: "FakeSearch | None" = None

        def __init__(self, query):
            self.query = query
            self.started = False
            self.running = True
            self.results = [("notes.txt", "/tmp"), ("todo.md", "/var")]
            FakeSearch.last_instance = self

        def start(self):
            self.started = True

        def is_running(self):
            return self.running

        def pop_result(self, block=True):
            if self.results:
                return self.results.pop(0)
            self.running = False
            return None

    monkeypatch.setattr(cli, "Search", FakeSearch)
    monkeypatch.setattr(cli.sys, "argv", ["cli.py", "notes"])
    app = cli.CLI()
    app.main()

    out = capsys.readouterr().out
    assert "Search results for: 'notes'" in out
    assert "-" * 40 in out
    assert os.path.join("/tmp", "notes.txt") in out
    assert os.path.join("/var", "todo.md") in out
    assert FakeSearch.last_instance is not None
    assert FakeSearch.last_instance.query == "notes"
    assert FakeSearch.last_instance.started is True


def test_interrupt_handler_stops_search():
    class FakeSearch:
        def __init__(self):
            self.stopped = False

        def stop(self):
            self.stopped = True

    app = cli.CLI()
    app.search = FakeSearch()

    with pytest.raises(SystemExit) as exc_info:
        app.interrupt_handler(None, None)

    assert app.search.stopped is True
    assert exc_info.value.code == 0


def test_cli_finds_random_file_within_20_seconds(capsys):
    temp_dir = Path.cwd()
    random_name = f"drill_cli_{uuid.uuid4().hex}.txt"
    random_file = temp_dir / random_name
    random_file.write_text("drill cli test file", encoding="utf-8")
    original_argv = sys.argv[:]
    app = cli.CLI()
    output = ""
    try:
        sys.argv = ["cli.py", random_name]
        thread = threading.Thread(target=app.main, daemon=True)
        thread.start()

        deadline = time.monotonic() + 20
        found = False
        while time.monotonic() < deadline:
            time.sleep(0.1)
            chunk = capsys.readouterr().out
            if chunk:
                output += chunk
            if str(random_file) in output:
                found = True
                break

        if not found:
            if hasattr(app, "search") and app.search is not None:
                app.search.stop()
            thread.join(timeout=5)
            pytest.fail(f"Drill did not find {random_file} within 20 seconds.\nOutput:\n{output}")

        if hasattr(app, "search") and app.search is not None:
            app.search.stop()
        thread.join(timeout=5)
    finally:
        sys.argv = original_argv
        random_file.unlink(missing_ok=True)
