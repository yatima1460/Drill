cmake_minimum_required(VERSION 3.22.1)


project (Drill CXX)

if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  # using Clang
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  # using GCC
  add_definitions("-Wall" "-Wextra" "-g" "-std=c++17" "-fPIC")
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Intel")
  # using Intel C++
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  # using Visual Studio C++
endif()


# Core
if(UNIX AND NOT APPLE) 
    message(STATUS "Linux")
    set(SUBSYSTEM "core/src/subsystem/linux.cpp")
endif()
if(WIN32)
    message(STATUS "Windows")
    set(SUBSYSTEM "core/src/subsystem/windows.cpp")
endif()
if(NOT UNIX AND APPLE)
    message(STATUS "Apple")
    set(SUBSYSTEM "core/src/subsystem/apple.cpp")
endif()
file(GLOB CORE_SRC_FILES core/src/*.cpp)
add_library(drill-core ${CORE_SRC_FILES} ${SUBSYSTEM})
set_property(TARGET drill-core PROPERTY CXX_STANDARD 17)

# CLI
include_directories(core/include)
include_directories(vendor/spdlog/include)
add_executable(drill-cli cli/CLI.cpp)
set_property(TARGET drill-cli PROPERTY CXX_STANDARD 17)
target_link_libraries(drill-cli drill-core)

# GTK
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
include_directories(${GTK3_INCLUDE_DIRS})
link_directories(${GTK3_LIBRARY_DIRS})
add_definitions(${GTK3_CFLAGS_OTHER})
file(GLOB SRC_FILES "gtk/src/*.cpp")
add_executable(drill-gtk ${SRC_FILES})
target_link_libraries(drill-gtk ${GTK3_LIBRARIES})
set_property(TARGET drill-gtk PROPERTY CXX_STANDARD 17)
## GTK assets
file(COPY gtk/assets DESTINATION ${CMAKE_BINARY_DIR})
target_link_libraries(drill-gtk drill-core)

set(CMAKE_CXX_CLANG_TIDY "clang-tidy;-checks=*")