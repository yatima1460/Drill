import sys
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QLineEdit, QTreeWidget, QTreeWidgetItem, QMessageBox
)
from PyQt6.QtGui import QAction
from PyQt6.QtGui import QGuiApplication

from PyQt6.QtCore import QTimer
import os
import subprocess
from search import Search

from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import QMenu
from PyQt6.QtCore import QMimeData, QSize
from PyQt6.QtGui import QClipboard
from PyQt6.QtGui import QFont  # Add this to your existing imports
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QStyle
import logging
import multiprocessing
from typing import Optional


from PyQt6.QtGui import QPixmap
from PyQt6.QtCore import QEvent

from utils import get_file_icon, get_resource_path
from drillentry import DrillEntry

class SearchWindow(QWidget):

    def fully_stop_search(self):
        """Stops the search and clears the results."""
        if self.search:
            # First stop the UI update so we don't get any stray results
            self.ui_update_timer.stop()
            self.search.stop()
            self.search = None
            self.tree.clear()
            self.setWindowTitle("Drill")
            logging.info("stopped previous search")
        

    def keyPressEvent(self, event):
        if event.key() == Qt.Key.Key_Escape:
            self.fully_stop_search()
            self.close()
        else:
            super().keyPressEvent(event)
    
    def open_file_on_double_click(self, item: QTreeWidgetItem):
        filename = item.text(0)
        path = item.text(1)
        full_path = os.path.join(path, filename)
        if os.path.exists(full_path):
            if sys.platform.startswith('darwin'):
                subprocess.call(('open', full_path))
            elif os.name == 'nt':
                os.startfile(full_path)
            elif os.name == 'posix':
                subprocess.call(('xdg-open', full_path))
        else:
            print(f"File not found: {full_path}")
    
    def resize_columns(self):
        viewport = self.tree.viewport()
        if viewport:
            total_width = viewport.width()
            self.tree.setColumnWidth(0, int(total_width * 0.45))  
            self.tree.setColumnWidth(1, int(total_width * 0.25))  
            self.tree.setColumnWidth(2, int(total_width * 0.10)) 
            self.tree.setColumnWidth(3, int(total_width * 0.125)) 
    
    
    def update_ui_every_frame(self):

        self.update_title()
        if self.dirty_columns:
            self.resize_columns()
            self.dirty_columns = False
        if self.search:
            result: Optional[DrillEntry] = self.search.pop_result()
            if result is None:
                return
      
            
            

            item = QTreeWidgetItem((result.name, result.containing_folder, result.size, result.formatted_time))
            item.setToolTip(0, result.name)
            item.setToolTip(1, result.containing_folder)
            item.setToolTip(2, result.size)
            item.setToolTip(3, result.formatted_time) 
            item.setTextAlignment(2, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)  # Size column is index 2
            self.tree.addTopLevelItem(item)
            item.setIcon(0, result.qicon)
            # Apply monospace to Size (column 2) and Date (column 3)
            
            item.setFont(2, self.monospace_font)  # Size column
            item.setFont(3, self.monospace_font)  # Date column

            SEARCH_LIMIT = 10000
            if self.tree.topLevelItemCount() > SEARCH_LIMIT:
                print("stopping search due to too many results")
                self.setWindowTitle(f"Drill - {SEARCH_LIMIT}+ items found, search stopped")
                self.ui_update_timer.stop()
                self.search.stop()
                self.search = None
            

    def update_title(self):
        if self.search:
            if self.search.is_done():
                self.setWindowTitle(f"Drill - {self.tree.topLevelItemCount()} items found - done")
            else:
                self.setWindowTitle(f"Drill - {self.tree.topLevelItemCount()} items found - {self.search.processes_count()} processes running - {self.search.total_to_scan()} directories to scan")
        else:
            self.setWindowTitle("Drill")

    def search_bar_keystroke(self, new_text):
        """Called on every keystroke, restarts the delay timer"""
        self.pending_search_text = new_text
        self.search_delay_timer.start(250)  # 500ms = 0.5 seconds

    def show_context_menu(self, pos):
        item = self.tree.itemAt(pos)
        if not item:
            return  # Only show menu for valid items

        menu = QMenu(self)

        # Icons
        style = self.style()
        #self.default_icon = self.style.standardIcon(QStyle.SP_MessageBoxQuestion)
        folder_icon = style.standardIcon(QStyle.StandardPixmap.SP_DirOpenIcon)

        open_action = QAction("Open", self)
        if sys.platform.startswith('darwin'):
            reveal_action_name = "Reveal in Finder"
        elif os.name == 'nt':
            reveal_action_name = "Reveal in Explorer"
        elif os.name == 'posix':
            reveal_action_name = "Reveal in File Manager"
        open_folder_action = QAction(folder_icon, reveal_action_name, self)
        copy_path_action = QAction("Copy Full Path", self)
        copy_date_action = QAction("Copy Date", self)
        copy_size_action = QAction("Copy Size", self)

        menu.addAction(open_action)
        menu.addAction(open_folder_action)
        menu.addSeparator()
        menu.addAction(copy_path_action)
        menu.addAction(copy_date_action)
        menu.addAction(copy_size_action)

        open_action.triggered.connect(lambda: self.open_file_on_double_click(item))
        open_folder_action.triggered.connect(lambda: self.open_item_in_folder(item))
        copy_path_action.triggered.connect(lambda: self.copy_to_clipboard(self.get_full_path(item)))
        copy_date_action.triggered.connect(lambda: self.copy_to_clipboard(item.text(3)))
        copy_size_action.triggered.connect(lambda: self.copy_to_clipboard(item.text(2)))
        viewport = self.tree.viewport()
        if viewport:
            menu.exec(viewport.mapToGlobal(pos))

    def get_full_path(self, item):
        filename = item.text(0)
        path = item.text(1)
        return os.path.join(path, filename)
    
    def open_item_in_folder(self, item):
        folder_path = item.text(1)
        full_path = os.path.join(item.text(1), item.text(0))
        print(full_path)
        if os.path.exists(folder_path):
            try:
                if sys.platform.startswith('darwin'):
                    logging.info("Selecting file in Finder: %s", full_path)
                    subprocess.call(['open', '-R', full_path])
                elif os.name == 'nt' or os.name == 'win32':
                    logging.info("Selecting file in Explorer: %s", full_path)
                    # Use a list to avoid issues with spaces in the path
                    subprocess.Popen(['explorer', '/select,', full_path])
                elif os.name == 'posix':
                    logging.info("Selecting file in xdg-open: %s", full_path)
                    subprocess.call(['xdg-open', folder_path])
                else:
                    logging.error("Unsupported OS for opening folder: %s", sys.platform)
                    QMessageBox.critical(self, "Error", f"Unsupported OS: {sys.platform}")
            except BaseException as e:
                logging.error("Error opening folder: %s", e)
                QMessageBox.critical(self, "Error", f"Failed to open folder: {e}")

    def copy_to_clipboard(self, text):
        clipboard = QApplication.clipboard()
        if clipboard:
            clipboard.setText(text)
            
    def __set_window_icon(self):
        if sys.platform.startswith('darwin'):
            try:
                icon = QIcon(get_resource_path(os.path.join("assets", "drill.svg")))  # Use .icns for macOS if available
                self.setWindowIcon(icon)
                # Set Dock icon (PyQt6 does not do this by default)
                app = QApplication.instance()
                if app:
                    pixmap = QPixmap(get_resource_path(os.path.join("assets", "drill.icns")))
                    if not pixmap.isNull():
                        app.setWindowIcon(icon)
                    # For Dock icon, use NSApplication API via PyObjC
                    try:
                        from AppKit import NSImage, NSApp
                        nsimage = NSImage.alloc().initByReferencingFile_(get_resource_path(os.path.join("assets", "drill.icns")))
                        if nsimage:
                            NSApp.setApplicationIconImage_(nsimage)
                    except ImportError:
                        pass  # PyObjC not installed, skip Dock icon
            except BaseException as e:
                logging.warning(f"Could not set macOS icon: {e}")
        else:
            self.setWindowIcon(QIcon(get_resource_path(os.path.join("assets", "drill.svg"))))

    def __init__(self):
        super().__init__()
        self.setWindowTitle("Drill")
        self.__set_window_icon()
        
        from heuristics import get_root_directories
        logging.info("Root directories:")
        for folder in get_root_directories():
            logging.info(f"Root directory: {folder}")
        
        # Get screen size and set window size to half
        screen = QGuiApplication.primaryScreen().geometry()
        width = screen.width() // 2
        height = screen.height() // 2
        self.resize(width, height)
        self.move((screen.width() - width) // 2, (screen.height() - height) // 2)

        # FIXME: ugly hack
        self.dirty_columns = True
        
        # Load monospace font used for some columns
        self.monospace_font = QFont("Monospace")  # or "Courier", "Consolas", etc.
        self.monospace_font.setStyleHint(QFont.StyleHint.Monospace)  # Ensures monospace fallback
        
        # UI Tick
        self.ui_update_timer = QTimer(self)
        self.ui_update_timer.timeout.connect(self.update_ui_every_frame)
        self.ui_update_timer.start(16)

        # The idea is that the search starts only after some inactivity (so we don't start a search for every keystroke)
        # First a keystroke is detected, then the keystroke timer will constantly reset until the user stops typing
        self.search_delay_timer = QTimer(self)
        self.search_delay_timer.setSingleShot(True)
        self.search_delay_timer.timeout.connect(self.search_input_changed)
        self.pending_search_text = None
        
        # Set up the search context
        self.search = None

        # Search bar
        self.search_bar = QLineEdit()
        self.search_bar.setFont(QFont("Arial", 24))
        self.search_bar.setPlaceholderText("Search...")
        self.search_bar.textChanged.connect(self.search_bar_keystroke)
        self.search_bar.installEventFilter(self)
        self.search_bar.setAccessibleName("Search bar")
        
        # Tree widget as a multi-column listbox
        self.tree = QTreeWidget()
        self.tree.setColumnCount(4)
        self.tree.setHeaderLabels(["Name", "Path", "Size", "Date"])
        self.tree.itemDoubleClicked.connect(self.open_file_on_double_click)
        self.tree.setRootIsDecorated(False)  # No tree expand/collapse arrows
        self.tree.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.tree.customContextMenuRequested.connect(self.show_context_menu)
        self.tree.setAlternatingRowColors(True)
        self.tree.setAccessibleName("Search results")
        self.tree.setIconSize(QSize(32, 32))
        self.tree.installEventFilter(self)
        
        # Smooth scrolling of the results list
        self.tree.setVerticalScrollMode(QTreeWidget.ScrollMode.ScrollPerPixel)
        
        # Set up the layout
        layout = QVBoxLayout()
        layout.addWidget(self.search_bar)
        layout.addWidget(self.tree)
        self.setLayout(layout)
        
        
    def eventFilter(self, source, event):
        # Down arrow in search bar: move to first result

                
        if source == self.search_bar and event.type() == QEvent.Type.KeyPress:
            if event.key() == Qt.Key.Key_Down:
                if self.tree.topLevelItemCount() > 0:
                    first_item = self.tree.topLevelItem(0)
                    self.tree.setCurrentItem(first_item)
                    self.tree.setFocus()
                    return True  # Event handled
        # Up arrow in tree: move back to search bar if at first item
        if source == self.tree and event.type() == QEvent.Type.KeyPress:
            
            if event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
                current_item = self.tree.currentItem()
                if current_item:
                    self.open_file_on_double_click(current_item)
                    return True  # Event handled
                
            if event.key() == Qt.Key.Key_Up:
                current = self.tree.currentItem()
                if current and self.tree.indexOfTopLevelItem(current) == 0:
                    self.search_bar.setFocus()
                    return True  # Event handled
        return super().eventFilter(source, event)


    def search_input_changed(self):
        """Called only after typing inactivity"""
        logging.info("search_input_changed triggered")

        self.fully_stop_search()
        
        if self.pending_search_text:
            stripped = self.pending_search_text.strip()
            if not stripped:
                self.pending_search_text = None
                return
            # Start a new search
            self.ui_update_timer.start(16)
            self.search = Search(self.pending_search_text)
            print("starting new search", self.pending_search_text)
            self.search.start()


    def closeEvent(self, event):
        if self.search:
            self.ui_update_timer.stop()
            self.search.stop()
            self.search = None
        event.accept()

if __name__ == "__main__":
    # Attach to console on Windows if frozen to see logs in terminal
    if sys.platform == 'win32' and getattr(sys, 'frozen', False):
        import ctypes
        # Try to attach to the parent process console
        if ctypes.windll.kernel32.AttachConsole(-1):
            # Redirect stdout and stderr to the console
            # Use 'w' mode and explicit encoding to avoid issues
            try:
                sys.stdout = open('CONOUT$', 'w', buffering=1, encoding='utf-8')
                sys.stderr = open('CONOUT$', 'w', buffering=1, encoding='utf-8')
                print("\n[Drill] Attached to console. Logging initialized.")
            except Exception:
                pass

    logging.basicConfig(level=logging.INFO, format='[%(processName)s][%(levelname)s]: %(message)s')
    multiprocessing.freeze_support()
    app = QApplication(sys.argv)
    window = SearchWindow()
    window.show()
    sys.exit(app.exec())