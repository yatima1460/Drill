# tests/test_window.py

import pytest
from PyQt6.QtWidgets import QApplication
import os
import sys

src_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src'))
sys.path.insert(0, src_path)

from main import SearchWindow  # Adjust import if your structure is different

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

@pytest.mark.skipif(not os.path.exists(r"C:\Program Files (x86)\Steam\steamapps\common\Hearts of Iron IV\hoi4.exe"), reason="hoi4.exe not found")
def test_find_hoi4(app, qtbot):
    window = SearchWindow()
    qtbot.addWidget(window)
    window.show()
    
    target_file = "hoi4.exe"
    window.search_bar.setText(target_file)
    
    # Wait for search to find the file. We use a longer timeout because it's a real search.
    # We check if any item in the tree has the name hoi4.exe
    def check_for_hoi4():
        for i in range(window.tree.topLevelItemCount()):
            item = window.tree.topLevelItem(i)
            if item.text(0).lower() == target_file.lower():
                return True
        return False

    qtbot.waitUntil(check_for_hoi4, timeout=10000)
    window.close()

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
