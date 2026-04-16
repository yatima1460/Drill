import os
import sys

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
        last_instance = None

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
    assert "/tmp/notes.txt" in out
    assert "/var/todo.md" in out
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
