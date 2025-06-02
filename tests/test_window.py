# tests/test_window.py
# tests/test_app_window.py

import pytest
from PyQt5.QtWidgets import QApplication
import os
import sys

src_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src'))
sys.path.insert(0, src_path)

from main import SearchWindow  # Adjust import if your structure is different

@pytest.fixture
def app(qtbot):
    return QApplication.instance() or QApplication([])

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
    assert window.windowTitle() == "Drill"
    
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
    assert window.windowTitle() == "Drill"
    
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
    
    window.search_bar.setText("document")
    
    qtbot.wait(1000)
    assert window.windowTitle() != "Drill"
    
    qtbot.wait(3000)
    
    window.close()
    assert not window.isVisible()
    
