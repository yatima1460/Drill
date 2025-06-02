


from PyQt5.QtGui import QIcon
from PyQt5.QtCore import QTimer, QFileInfo
from PyQt5.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QLineEdit, QTreeWidget, QTreeWidgetItem, QDesktopWidget, QHeaderView, QMessageBox, QFileIconProvider
)

import os
import logging
from PyQt5.QtWidgets import QStyle
from typing import Optional, Tuple, List
from functools import lru_cache

@lru_cache(maxsize=512)
def get_file_icon(path: str) -> Optional[QIcon]:
    """
    Get the file icon for a given path or None, with memoization.
    """
    try:
        file_info = QFileInfo(path)
        file_icon = QFileIconProvider().icon(file_info)
        return file_icon
    except BaseException as e:
        logging.error(f"Error getting file icon: {e}")
        return None

    