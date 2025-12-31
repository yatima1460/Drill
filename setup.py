from setuptools import find_packages
import sys
import os

# Try to import cx_Freeze, but don't fail if it's not present
try:
    from cx_Freeze import setup, Executable
    HAS_CX_FREEZE = True
except ImportError:
    from setuptools import setup
    Executable = None
    HAS_CX_FREEZE = False

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
        "threading",
        "sortedcontainers"
    ] + list(find_packages(where=".")),
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
        "transformers",
        "sortedcontainers-stubs"
    ],
    "include_files": [
        ("src/assets", "assets")
    ],
    "include_msvcr": True,
    "path": ["src"] + sys.path
}

# Platform-specific options
if sys.platform == "win32":
    base = "gui"
    build_exe_options.update(
        {
            "include_msvcr": True,
        }
    )
    target_name = "Drill.exe"
else:
    base = None
    target_name = "Drill"

executables = []
if HAS_CX_FREEZE and Executable is not None:
    executables = [
        Executable(
            script="src/main.py",
            target_name=target_name,
            base=base,
            icon="src/assets/drill.icns" if sys.platform != "win32" else "src/assets/drill.ico"
        ),
    ]

# If we are building a wheel, we don't want cx_Freeze to interfere
if "bdist_wheel" in sys.argv or "sdist" in sys.argv:
    from setuptools import setup
    setup_kwargs = {}
else:
    setup_kwargs = {"executables": executables}

setup(
    name="drill",
    version="0.0.1",
    description="Search files without indexing",
    packages=find_packages(where=".", exclude=["tests", "tests.*"]),
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
    **setup_kwargs
)
