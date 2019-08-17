cmake_minimum_required(VERSION 3.0.0)
set (CMAKE_C_STANDARD 11)

project(Drill VERSION 0.1.0)

include(CTest)
enable_testing()



option(BUILD_CORE "Enable building core" ON)
option(BUILD_CLI "Enable building cli" OFF)
option(BUILD_GTK "Enable building gtk" OFF)


if(BUILD_CORE)
    add_subdirectory(core)
endif()
if(BUILD_CLI)
    add_subdirectory(cli)
    set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "drill-cli")
endif()
if(BUILD_GTK)
    add_subdirectory(gtk)
endif()




set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})
include(CPack)
