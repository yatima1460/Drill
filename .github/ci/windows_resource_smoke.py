"""Link Drill's build script with MSVC and read every icon through Win32."""

import ctypes
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile


def icon_from_exe(exe, source):
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    pointer = ctypes.c_void_p
    for name in ("LoadLibraryExW", "FindResourceW", "LoadResource", "LockResource"):
        getattr(kernel, name).restype = pointer
    module = pointer(kernel.LoadLibraryExW(str(exe), None, 2))  # LOAD_LIBRARY_AS_DATAFILE
    if not module:
        raise ctypes.WinError(ctypes.get_last_error())

    def resource(kind, resource_id):
        info = pointer(kernel.FindResourceW(module, pointer(resource_id), pointer(kind)))
        handle = pointer(kernel.LoadResource(module, info))
        data = kernel.LockResource(handle)
        if not data:
            raise ctypes.WinError(ctypes.get_last_error())
        return ctypes.string_at(data, kernel.SizeofResource(module, info))

    try:
        group = resource(14, 1)  # RT_GROUP_ICON, ID in drill.rc
        assert group[:6] == source[:6]
        count = struct.unpack_from("<H", source, 4)[0]
        assert count > 0
        for i in range(count):
            image = 6 + i * 16
            entry = 6 + i * 14
            assert group[entry:entry + 12] == source[image:image + 12]
            size, offset = struct.unpack_from("<II", source, image + 8)
            icon_id = struct.unpack_from("<H", group, entry + 12)[0]
            assert resource(3, icon_id) == source[offset:offset + size]  # RT_ICON
        print(f"Verified all {count} icon frames from the linked executable")
    finally:
        kernel.FreeLibrary(module)


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix="drill msvc ") as temp:
        project = Path(temp)
        assets = project / "src/assets"
        assets.mkdir(parents=True)
        shutil.copy(root / "build.rs", project)
        for name in ("drill.rc", "drill.ico"):
            shutil.copy(root / "src/assets" / name, assets)
        (project / "src/main.rs").write_text("fn main() {}\n")
        (project / "Cargo.toml").write_text('[package]\nname="drill"\nversion="0.0.0"\nedition="2021"\n')
        subprocess.run(
            ["cargo", "build", "--offline", "--manifest-path", str(project / "Cargo.toml"),
             "--target-dir", str(project / "target")],
            check=True,
        )
        icon_from_exe(project / "target/debug/drill.exe", (assets / "drill.ico").read_bytes())
