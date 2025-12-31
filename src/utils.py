


from PyQt6.QtGui import QIcon
from PyQt6.QtCore import QTimer, QFileInfo
from PyQt6.QtWidgets import (
    QFileIconProvider
)

import os
import sys
import logging
from typing import Optional, Tuple, List
from functools import lru_cache

def get_resource_path(relative_path: str) -> str:
    """ Get absolute path to resource, works for dev and for bundled apps """
    if hasattr(sys, '_MEIPASS'):
        return os.path.join(sys._MEIPASS, relative_path)
    
    # For other bundlers or dev
    base_path = os.path.dirname(os.path.abspath(__file__))
    
    # Handle cases where we might be running from inside a zip (e.g. py2exe)
    if '.zip' in base_path:
        # If the path contains .zip, we are likely inside a library.zip
        # We want to look for assets in the same directory as the zip file
        parts = base_path.split(os.sep)
        for i, part in enumerate(parts):
            if part.endswith('.zip'):
                base_path = os.sep.join(parts[:i])
                break

    return os.path.join(base_path, relative_path)

_ICON_PROVIDER = None

def get_icon_provider():
    global _ICON_PROVIDER
    if _ICON_PROVIDER is None:
        _ICON_PROVIDER = QFileIconProvider()
    return _ICON_PROVIDER

@lru_cache(maxsize=100000)
def get_file_icon(path: str) -> Optional[QIcon]:
    """
    Get the file icon for a given path or None, with memoization.
    """
    try:
        file_info = QFileInfo(path)
        file_icon = get_icon_provider().icon(file_info)
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