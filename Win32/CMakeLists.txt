cmake_minimum_required (VERSION 2.8.11)


project(DrillWin32)


add_executable(DrillWin32 WIN32  ui.cpp windows.rc)

include_directories(../CoreCpp/Include)

target_link_libraries(DrillWin32 UxTheme.lib)