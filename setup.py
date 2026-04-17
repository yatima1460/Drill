from setuptools import find_packages
import sys
import os

APP_VERSION = os.environ.get("DRILL_VERSION", "1.0.0")

# Try to import cx_Freeze, but don't fail if it's not present
try:
    from cx_Freeze import setup, Executable
    HAS_CX_FREEZE = True
except ImportError:
    from setuptools import setup
    Executable = None
    HAS_CX_FREEZE = False

# Build options for all platforms
# NOTE: Keep stdlib `re` fully present in frozen builds. On Python 3.14 + Arch,
# incomplete `re` packaging can break startup with:
# "ImportError: cannot import name '_compiler' ... /opt/drill/lib/re/__init__.pyc".
build_exe_options = {
    "packages": [
        "sortedcontainers"
    ],
    "includes": [
        "src",
        "PyQt6.QtCore",
        "PyQt6.QtGui",
        "PyQt6.QtWidgets",
        "re",
        "re._casefix",
        "re._compiler",
        "re._constants",
        "re._parser",
    ],
    "excludes": [
        "unittest", 
        "pydoc", 
        "test", 
        # Exclude heavy/unused Qt modules to keep frozen bundles lean.
        "PyQt6.QtBluetooth",
        "PyQt6.QtMultimedia",
        "PyQt6.QtMultimediaWidgets",
        "PyQt6.QtNetworkAuth",
        "PyQt6.QtNfc",
        "PyQt6.QtPdf",
        "PyQt6.QtPdfWidgets",
        "PyQt6.QtPositioning",
        "PyQt6.QtSql",
        "PyQt6.QtSensors",
        "PyQt6.QtQml", 
        "PyQt6.QtQuick",
        "PyQt6.QtQuick3D",
        "PyQt6.QtQuickWidgets",
        "PyQt6.QtTextToSpeech",
        "PyQt6.QtWebChannel",
        "PyQt6.QtWebEngineCore",
        "PyQt6.QtWebEngineWidgets",
        "ai",
        "mlx",
        "mlx_lm",
        "transformers",
        "sortedcontainers-stubs"
    ],
    "include_files": [
        ("src/assets", "assets")
    ],
    "bin_excludes": [
        # Drop SQL/multimedia plugin binaries not required by Drill.
        "libqsqlodbc.dylib",
        "libqsqlite.dylib",
        "libiodbc.2.dylib",
        "libqtaudio_coreaudio.dylib",
        "libqtmedia_audioengine.dylib",
        "libqtmedia_ffmpeg.dylib",
        "libqtmedia_wmfengine.dll",
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
    version=APP_VERSION,
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
