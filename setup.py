from cx_Freeze import setup, Executable  # type: ignore
from setuptools import find_packages
import sys
import os
from PyQt6.QtCore import QLibraryInfo

# Build options for all platforms
build_exe_options = {
    "packages": [
        "PyQt6.QtCore",
        "PyQt6.QtGui",
        "PyQt6.QtWidgets",
        "multiprocessing",
        "logging",
        "os",
        "sys",
        "threading"
    ] + list(find_packages("src")),
    "excludes": [
        "unittest", 
        "pydoc", 
        "test", 
        "PyQt6.QtQml", 
        "PyQt6.QtQuick",
        "PyQt6.QtQuick3D",
        "PyQt6.QtQuickWidgets",
        "ai",
        "mlx",
        "mlx_lm",
        "transformers"
    ],
    "include_files": [
        ("src/assets", "assets")
    ],
    "include_msvcr": True,
    "path": ["src"] + sys.path
}

# Platform-specific options
if sys.platform == "win32":
    base = "Win32GUI"
    build_exe_options.update(
        {
            "include_msvcr": True,
        }
    )
    target_name = "Drill.exe"
else:
    base = None
    target_name = "Drill"

executables = [
    Executable(
        script="src/main.py",
        target_name=target_name,
        base=base,
        icon="src/assets/drill.icns" if sys.platform != "win32" else "src/assets/drill.ico"
    ),
]

build_options = {
    "packages": list(find_packages("src")),
    "excludes": ["unittest", "pydoc", "test"],
}

setup(
    name="drill",
    version="0.0.1",
    description="Search files without indexing",
    options={
        "build_exe": build_exe_options,
        "bdist_mac": {
            "bundle_name": "Drill",
            "iconfile": "src/assets/drill.icns",
            "codesign_identity": "-",
        },
        "bdist_dmg": {
            "applications_shortcut": True,
            "background": "builtin-arrow"
        },
    },
    executables=executables,
)
