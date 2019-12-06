{

    "targets": [
        {
            "target_name": "drill-search-node-bindings",
            "sources": ["main.cpp"],
            "include_dirs": ['<(module_root_dir)/../Core/', '<(module_root_dir)/../Core/spdlog/include'],
            "libraries": ["<(module_root_dir)/../Core/libDrillCore.a"],
            "cflags_cc": [
                "-std=c++17 -fpermissive -fexceptions -fPIC"
            ]
        }
    ]
}
