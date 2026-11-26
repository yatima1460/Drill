"""Check the Finder records in the mounted installer."""

import sys
from pathlib import Path

from ds_store import DSStore
from mac_alias import Alias
from mac_alias.bookmark import kBookmarkCNIDPath, kBookmarkPath

volume = Path(sys.argv[1])
visible = {entry.name for entry in volume.iterdir() if not entry.name.startswith(".")}
assert visible == {"Drill.app", "Applications"}, visible
applications = volume / "Applications"
assert applications.readlink() == Path("/Applications") and applications.is_dir()
background = volume / ".background.png"
with DSStore.open(str(volume / ".DS_Store"), "r") as store:
    assert store["."]["vSrn"] == (b"long", 1)
    assert store["."]["icvl"] == (b"type", b"icnv")
    window = store["."]["bwsp"]
    assert window["WindowBounds"] == "{{140, 120}, {600, 300}}" and not window["ShowToolbar"]
    options = store["."]["icvp"]
    assert options["arrangeBy"] == "none" and options["iconSize"] == 96
    assert options["backgroundType"] == 2
    target = Alias.from_bytes(options["backgroundImageAlias"]).target
    assert target.filename == background.name and target.cnid == background.stat().st_ino
    bookmark = store["."]["pBBk"]
    assert bookmark[kBookmarkPath] == [background.name]
    assert bookmark[kBookmarkCNIDPath] == [background.stat().st_ino]
    assert store["Drill.app"]["Iloc"] == (150, 135)
    assert store["Applications"]["Iloc"] == (450, 135)
