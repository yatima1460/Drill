import os
import sys
import time
from pathlib import Path

src_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src'))
sys.path.insert(0, src_path)

import search


def test_token_search_exact_and_fuzzy():
    assert search.token_search('Project Notes.txt', 'project notes', fuzzy=False)
    assert not search.token_search('Project Notes.txt', 'projecx notes', fuzzy=False)
    assert search.token_search('Project Notes.txt', 'projecx notes', fuzzy=True)


def test_search_finds_file_in_temp_root(monkeypatch, tmp_path: Path):
    target = tmp_path / 'drill_functional_target.txt'
    target.write_text('functional test', encoding='utf-8')

    monkeypatch.setattr(search, 'get_root_directories', lambda: [str(tmp_path)])

    engine = search.Search('drill_functional_target')
    engine.start()

    found = False
    deadline = time.monotonic() + 5
    try:
        while time.monotonic() < deadline:
            result = engine.pop_result()
            if result is not None and result.path == str(target):
                found = True
                break
            if engine.is_done() and engine.result_queue.empty():
                break
            time.sleep(0.01)
    finally:
        engine.stop()

    assert found, f'Expected to find {target}, but no matching result was produced.'
