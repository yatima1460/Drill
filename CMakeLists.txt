cmake_minimum_required(VERSION 3.22.1)


project (Drill C CXX)

set(CMAKE_VERBOSE_MAKEFILE OFF)

# log.c
add_library(log-c vendor/log.c/src/log.c)
set_property(TARGET log-c PROPERTY C_STANDARD 17)

# Core
if(UNIX AND NOT APPLE) 
    message(STATUS "Linux")
    set(OS_LINUX true)
    set(SUBSYSTEM "core/src/subsystem/linux.cpp")
endif()
if(WIN32)
    set(OS_WINDOWS true)
    message(STATUS "Windows")
    set(SUBSYSTEM "core/src/subsystem/windows.cpp")
endif()
if(NOT UNIX AND APPLE)
    set(OS_APPLE true)
    message(STATUS "Apple")
    set(SUBSYSTEM "core/src/subsystem/apple.cpp")
endif()
file(GLOB CORE_SRC_FILES core/src/*.cpp core/src/*.c)
add_library(drill-core ${CORE_SRC_FILES} ${SUBSYSTEM})
set_property(TARGET drill-core PROPERTY CXX_STANDARD 17)
# CLI

add_executable(drill-cli cli/CLI.cpp)
set_property(TARGET drill-cli PROPERTY CXX_STANDARD 17)
target_link_libraries(drill-cli log-c)
target_link_libraries(drill-cli drill-core)


# GTK
if(OS_LINUX) 
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
    target_link_libraries(drill-gtk log-c)
    target_link_libraries(drill-gtk drill-core)

endif()

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O0 -g3")
endif()
    
if (CMAKE_BUILD_TYPE STREQUAL "Release")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3")
endif()

# if (CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
#     set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
# endif()

# if (CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
#     set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
# endif()

if ("${CMAKE_CXX_COMPILER_ID}" MATCHES "Clang")
  MESSAGE("Clang")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wno-unused-parameter ")
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
  MESSAGE("GNU")
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Intel")
  MESSAGE("Intel")
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
  MESSAGE("MSVC")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -W4")
endif()

include_directories(vendor/log.c/src)
include_directories(core/include)
# include_directories(vendor/spdlog/include)


set(CMAKE_CXX_CLANG_TIDY "clang-tidy;-checks=*")


find_package(Git)
if(GIT_EXECUTABLE)
  get_filename_component(SRC_DIR . DIRECTORY)
  # Generate a git-describe version string from Git repository tags

  

  message(${GIT_EXECUTABLE})

  execute_process(COMMAND  ${GIT_EXECUTABLE} rev-parse --short HEAD  OUTPUT_VARIABLE DRILL_VERSION)
  

endif()

# Final fallback: Just use a bogus version string that is semantically older
# than anything else and spit out a warning to the developer.
if(NOT DEFINED DRILL_VERSION)
  set(DRILL_VERSION 0.0.0-unknown)
  message(WARNING "Failed to determine DRILL_VERSION from Git tags. Using default version \"${DRILL_VERSION}\".")
endif()

add_definitions(-DDRILL_VERSION=\"${DRILL_VERSION}\")

