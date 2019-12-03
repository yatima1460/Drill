cmake_minimum_required(VERSION 3.0.0)
project(Drill VERSION 0.1.0)

include(CTest)
enable_testing()

if (CMAKE_BUILD_TYPE MATCHES Release)
    add_definitions(-DDrill_Release)
endif()
if (CMAKE_BUILD_TYPE MATCHES Debug)
    add_definitions(-DDrill_Debug)
endif()



add_subdirectory(CLI)

set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})
include(CPack)
