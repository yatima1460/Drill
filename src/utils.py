


from PyQt6.QtGui import QIcon
from PyQt6.QtCore import QTimer, QFileInfo
from PyQt6.QtWidgets import (
    QFileIconProvider
)

import os
import logging
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

@lru_cache(maxsize=512)
def get_file_modified_time(path: str) -> Optional[float]:
    """
    Get the last modified time of a file.
    Returns None if the file does not exist or an error occurs.
    """
    try:
        file_info = QFileInfo(path)
        if file_info.exists():
            return file_info.lastModified().toSecsSinceEpoch()
        else:
            return None
    except BaseException as e:
        logging.error(f"Error getting file modified time: {e}")
        return None