
import os
import sys
import logging
from typing import Optional, Any, TYPE_CHECKING
from functools import lru_cache

if TYPE_CHECKING:
    from PyQt6.QtGui import QIcon

try:
    from PyQt6.QtCore import QFileInfo
    from PyQt6.QtWidgets import QFileIconProvider
    _QT_ICON_AVAILABLE = True
except BaseException:
    QFileInfo = None  # type: ignore[assignment]
    QFileIconProvider = None  # type: ignore[assignment]
    _QT_ICON_AVAILABLE = False

def get_resource_path(relative_path: str) -> str:
    """ Get absolute path to resource, works for dev and for bundled apps """
    # 1. Check PyInstaller
    meipass = getattr(sys, "_MEIPASS", None)
    if isinstance(meipass, str):
        return os.path.join(meipass, relative_path)
    
    # 2. Check cx_Freeze / frozen apps
    if getattr(sys, 'frozen', False):
        base_path = os.path.dirname(sys.executable)
        # Try directly in base path
        path = os.path.join(base_path, relative_path)
        if os.path.exists(path):
            return path
        # Try in lib folder (sometimes cx_Freeze puts things there)
        path = os.path.join(base_path, 'lib', relative_path)
        if os.path.exists(path):
            return path

    # 3. For dev or other cases
    # Get the directory of the current file (src/)
    base_path = os.path.dirname(os.path.abspath(__file__))
    
    # Handle cases where we might be running from inside a zip (e.g. py2exe)
    if '.zip' in base_path:
        parts = base_path.split(os.sep)
        for i, part in enumerate(parts):
            if part.endswith('.zip'):
                base_path = os.sep.join(parts[:i])
                break
    
    # Try relative to base_path
    path = os.path.join(base_path, relative_path)
    if os.path.exists(path):
        return path
        
    # Try one level up (if we are in src/ and assets is in root)
    path = os.path.join(os.path.dirname(base_path), relative_path)
    if os.path.exists(path):
        return path

    return os.path.join(base_path, relative_path)

_ICON_PROVIDER = None

def get_icon_provider():
    if not _QT_ICON_AVAILABLE or QFileIconProvider is None:
        return None
    global _ICON_PROVIDER
    if _ICON_PROVIDER is None:
        _ICON_PROVIDER = QFileIconProvider()
    return _ICON_PROVIDER

@lru_cache(maxsize=100000)
def get_file_icon(path: str) -> Optional["QIcon"]:
    """
    Get the file icon for a given path or None, with memoization.
    """
    if not _QT_ICON_AVAILABLE or QFileInfo is None:
        return None
    try:
        file_info = QFileInfo(path)
        provider = get_icon_provider()
        if provider is None:
            return None
        file_icon = provider.icon(file_info)
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
        return os.path.getmtime(path) if os.path.exists(path) else None
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


def report_search_start_error(error: BaseException) -> None:
    """
    Always log search startup failures.
    If a Qt GUI app is active, also show a QMessageBox.
    """
    message = f"Failed to start search: {error}"
    logging.exception(message)

    try:
        from PyQt6.QtWidgets import QApplication, QMessageBox

        if QApplication.instance() is not None:
            QMessageBox.critical(None, "Search Error", message)
    except BaseException:
        # CLI/headless mode or missing Qt: logging is enough.
        pass
