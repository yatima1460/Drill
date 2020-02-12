
cmake_minimum_required(VERSION 2.8.9)


project (DrillGTK)


# Use the package PkgConfig to detect GTK+ headers/library files
FIND_PACKAGE(PkgConfig REQUIRED)
PKG_CHECK_MODULES(GTK3 REQUIRED gtk+-3.0)

# Setup CMake to use GTK+, tell the compiler where to look for headers
# and to the linker where to look for libraries
INCLUDE_DIRECTORIES(${GTK3_INCLUDE_DIRS})
LINK_DIRECTORIES(${GTK3_LIBRARY_DIRS})

# Add other flags to the compiler
ADD_DEFINITIONS(${GTK3_CFLAGS_OTHER})

file( GLOB SRCS *.cpp *.hpp )

add_executable(DrillGTK ${SRCS})


# Link the target to the GTK+ libraries
TARGET_LINK_LIBRARIES(DrillGTK ${GTK3_LIBRARIES})


file(COPY ../Assets DESTINATION ${CMAKE_BINARY_DIR})