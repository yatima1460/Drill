
project(DrillGTK C CXX)

# Set the minimum version of cmake required to build this project
cmake_minimum_required(VERSION 3.10)

# Use the package PkgConfig to detect GTK+ headers/library files
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
# Setup CMake to use GTK+, tell the compiler where to look for headers
# and to the linker where to look for libraries
include_directories(${GTK3_INCLUDE_DIRS})
link_directories(${GTK3_LIBRARY_DIRS})
# Add other flags to the compiler
add_definitions(${GTK3_CFLAGS_OTHER})
# Add an executable compiled from hello.c
file(GLOB SRC_FILES src/*.cpp)
add_executable(DrillGTK ${SRC_FILES})
# Link the target to the GTK+ libraries
target_link_libraries(DrillGTK ${GTK3_LIBRARIES})




set_property(TARGET DrillGTK PROPERTY CXX_STANDARD 17)

# spdlog
include_directories(../core/spdlog/include)

file(COPY assets DESTINATION ${CMAKE_BINARY_DIR})

# # Add Drill Core
# include_directories(../core/include)
# add_subdirectory(../core ${CMAKE_CURRENT_BINARY_DIR}/core)
# target_link_libraries(DrillGTK DrillCore)