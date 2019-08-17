cmake_minimum_required(VERSION 3.0.0)
set (CMAKE_C_STANDARD 11)


# here we specify that the project is C language only, so the default
# C compiler on the system will be used
project(DrillCLI C)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../core)
link_directories(${CMAKE_SOURCE_DIR}/../core)

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../core ${CMAKE_CURRENT_BINARY_DIR}/core)

add_executable(DrillCLI cli.c)

set_target_properties(DrillCore PROPERTIES LINKER_LANGUAGE C)
target_link_libraries (DrillCLI LINK_PUBLIC DrillCore)

IF (WIN32)
  # set stuff for windows
ELSE()
    target_link_libraries (DrillCLI LINK_PUBLIC pthread)
ENDIF()


set_target_properties(DrillCLI PROPERTIES OUTPUT_NAME "cli.elf")


# set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "drill-cli")



