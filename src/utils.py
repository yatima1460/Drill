


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
    
    
@lru_cache(maxsize=512)
def human_readable(size, suffix='B'):
    # Uses KB, MB, GB, TB, etc. (not KiB, MiB...)
    units = ['', 'K', 'M', 'G', 'T', 'P', 'E', 'Z']
    if 0 < abs(size) < 1024:
        # For any nonzero value less than 1024, show as "1 KB"
        return "1 KB"
    elif size == 0:
        return "Empty"
    for unit in units:
        if abs(size) < 1024.0:
            return f"{size:3.0f} {unit}{suffix}"
        size /= 1024.0
    return f"{size:.1f} Y{suffix}"