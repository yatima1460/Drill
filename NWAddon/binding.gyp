{

  "targets": [
    {
      "target_name": "drill-search-node-bindings",
      "sources": [ "main.cpp" ],
      "include_dirs": ['<(module_root_dir)/../Core/'],
      "libraries": [ "<(module_root_dir)/../Core/libDrillCore.a" ]
    }
  ]
}