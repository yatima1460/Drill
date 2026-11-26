"""Write Finder's icon view using a background alias bound to this volume."""

import sys
from pathlib import Path

from ds_store import DSStore
from mac_alias import Alias, Bookmark
from mac_alias.bookmark import URL, kBookmarkVolumePath, kBookmarkVolumeURL


def write_layout(volume):
    background = Alias.for_file(str(volume / ".background.png"))
    # Keep the temporary build mount out of both portable Finder references.
    background.volume.posix_path = "/Volumes/Drill"
    background.target.folder_name = "Drill"
    bookmark = Bookmark.for_file(str(volume / ".background.png"))
    bookmark[kBookmarkVolumePath] = "/Volumes/Drill"
    bookmark[kBookmarkVolumeURL] = URL("file:///Volumes/Drill")
    with DSStore.open(str(volume / ".DS_Store"), "w+") as store:
        store["."]["vSrn"] = (b"long", 1)
        store["."]["pBBk"] = bookmark
        store["."]["icvl"] = (b"type", b"icnv")
        store["."]["bwsp"] = {
            "WindowBounds": "{{140, 120}, {600, 300}}",
            "SidebarWidth": 180,
            "ShowToolbar": False,
            "ShowSidebar": False,
            "ContainerShowSidebar": False,
            "ShowTabView": False,
            "PreviewPaneVisibility": False,
            "ShowStatusBar": False,
            "ShowPathbar": False,
        }
        store["."]["icvp"] = {
            "viewOptionsVersion": 1,
            "backgroundColorRed": 1.0,
            "backgroundColorGreen": 1.0,
            "backgroundColorBlue": 1.0,
            "backgroundType": 2,
            "backgroundImageAlias": background.to_bytes(),
            "arrangeBy": "none",
            "gridOffsetX": 0.0,
            "gridOffsetY": 0.0,
            "gridSpacing": 100.0,
            "showIconPreview": False,
            "showItemInfo": False,
            "iconSize": 96.0,
            "textSize": 14.0,
            "labelOnBottom": True,
            "scrollPositionX": 0.0,
            "scrollPositionY": 0.0,
        }
        store["Drill.app"]["Iloc"] = (150, 135)
        store["Applications"]["Iloc"] = (450, 135)


if __name__ == "__main__":
    write_layout(Path(sys.argv[1]))
