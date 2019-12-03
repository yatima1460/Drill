cmake_minimum_required(VERSION 3.0.0)
project (DrillCore CXX)


add_definitions("-Wall" "-Wextra" "-g" )
file(GLOB SRC_FILES *.cpp)

add_subdirectory(spdlog)

include_directories(spdlog/include)


if (CMAKE_BUILD_TYPE MATCHES Release)
    message(STATUS "Drill_Release")
    add_definitions(-DDrill_Release)
endif()
if (CMAKE_BUILD_TYPE MATCHES Debug)
    message(STATUS "Drill_Debug")
    add_definitions(-DDrill_Debug)
endif()



# if(NOT LINUX) should work, too, if you need that
if(UNIX AND NOT APPLE) 
    message(STATUS "Linux")
    add_definitions("-lpthread" )
    set(SUBSYSTEM "Subsystem/Linux.cpp")
endif()

if(WIN32)
    message(STATUS "Windows")
    set(SUBSYSTEM "Subsystem/Windows.cpp")
endif()

if(NOT UNIX AND APPLE)
    message(STATUS "Apple")
    set(SUBSYSTEM "Subsystem/Apple.cpp")
endif()

add_library(DrillCore ${SRC_FILES} ${SUBSYSTEM})

set_property(TARGET DrillCore PROPERTY CXX_STANDARD 20)


