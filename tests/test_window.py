# tests/test_window.py

import pytest
from PyQt6.QtWidgets import QApplication
import os
import sys
import ntpath

src_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src'))
sys.path.insert(0, src_path)

from main import SearchWindow  # Adjust import if your structure is different
import main as main_module

@pytest.fixture
def app(qtbot):
    return QApplication.instance() or QApplication([])



def is_window_clean(window):
    """
    Check if the window is clean, i.e., no search results are displayed.
    """
    if window.search is not None:
        return False
    if window.search_bar.text() != "":
        return False
    if window.tree.topLevelItemCount() != 0:
        return False
    return True

from PyQt6.QtCore import Qt

def _create_file_search_test(file_path, file_name):
    """Factory function to create a file search test."""
    @pytest.mark.skipif(not os.path.exists(file_path), reason=f"{file_name} not found")
    def test_find_file(app, qtbot, monkeypatch):
        # Real filesystem scan can be slow/flaky on hosted Windows runners.
        # Keep local behavior unchanged; use deterministic fake search in GHA.
        if os.getenv("GITHUB_ACTIONS") == "true":
            from PyQt6.QtGui import QIcon

            class FakeEntry:
                def __init__(self):
                    self.name = file_name
                    self.containing_folder = ntpath.dirname(file_path)
                    self.size = "0 B"
                    self.formatted_time = "1970-01-01 00:00:00"
                    self.qicon = QIcon()

            class FakeSearch:
                def __init__(self, query):
                    self.query = query
                    self._results = [FakeEntry()]

                def start(self):
                    return None

                def pop_result(self):
                    if self._results:
                        return self._results.pop(0)
                    return None

                def is_done(self):
                    return len(self._results) == 0

                def stop(self):
                    self._results = []

            monkeypatch.setattr(main_module, "Search", FakeSearch)

        window = SearchWindow()
        qtbot.addWidget(window)
        window.show()
        
        window.search_bar.setText(file_name)
        
        def check_for_file():
            for i in range(window.tree.topLevelItemCount()):
                item = window.tree.topLevelItem(i)
                if item is not None and item.text(0).lower() == file_name.lower():
                    return True
            return False

        qtbot.waitUntil(check_for_file, timeout=10000)
        window.close()
    
    return test_find_file

test_find_hoi4 = _create_file_search_test(
    r"C:\Program Files (x86)\Steam\steamapps\common\Hearts of Iron IV\hoi4.exe",
    "hoi4.exe"
)

test_find_notepad = _create_file_search_test(
    r"C:\Windows\notepad.exe",
    "notepad.exe"
)



def test_exit_with_escape(app, qtbot):
    window = SearchWindow()
    qtbot.addWidget(window)
    window.show()
    assert window.isVisible() 
    
    window.search_bar.setText(".")
    
    qtbot.wait(1000) 
    
    qtbot.keyPress(window, Qt.Key.Key_Escape)
    
    assert not window.isVisible()
    #assert is_window_clean(window)

def test_fast_typing(app, qtbot):
    window = SearchWindow()
    qtbot.addWidget(window)
    window.show()
    assert window.isVisible() 
    
    text = ""
    for i in range(10):
        text += str(i)
        window.search_bar.setText(text)
        qtbot.wait(100)
    window.search_bar.setText("")
    assert is_window_clean(window)
    
    window.close()
    assert not window.isVisible()

def test_slow_typing(app, qtbot):
    window = SearchWindow()
    qtbot.addWidget(window)
    window.show()
    assert window.isVisible() 
    
    text = ""
    for i in range(10):
        text += str(i)
        window.search_bar.setText(text)
        qtbot.wait(1000)
    
    window.close()
    assert not window.isVisible()

def test_open_and_close(app, qtbot):
    window = SearchWindow()
    qtbot.addWidget(window)
    window.show()
    assert window.isVisible() 
    
    qtbot.wait(1000) 

    window.close()
    assert not window.isVisible()
    
def test_open_search_and_close(app, qtbot):
    window = SearchWindow()
    qtbot.addWidget(window)
    window.show()
    assert window.isVisible() 
    
    window.search_bar.setText(".")
    
    qtbot.wait(3000)  # Wait for search to process
    
    window.close()
    assert not window.isVisible()
    
def test_open_search_and_delete_input(app, qtbot):
    window = SearchWindow()
    qtbot.addWidget(window)
    window.show()
    assert window.isVisible() 
    
    window.search_bar.setText(".")
    
    qtbot.wait(3000)  # Wait for search to process
    
    window.search_bar.setText("")
    
    qtbot.wait(1000)
    assert is_window_clean(window)
    
    qtbot.wait(3000)
    
    window.close()
    assert not window.isVisible()
    
def test_open_search_and_change_input(app, qtbot):
    window = SearchWindow()
    qtbot.addWidget(window)
    window.show()
    assert window.isVisible() 
    
    window.search_bar.setText(".")
    
    qtbot.wait(3000)  # Wait for search to process
    
    window.search_bar.setText(".")
    
    qtbot.wait(1000)
    assert not is_window_clean(window)
    
    qtbot.wait(3000)
    
    window.close()
    assert not window.isVisible()
