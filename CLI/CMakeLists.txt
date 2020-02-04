cmake_minimum_required(VERSION 2.8.9)

project (DrillCLI CXX)


if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  # using Clang
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  # using GCC
  add_definitions("-Wall" "-Wextra" "-g" "-std=c++17")
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Intel")
  # using Intel C++
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  # using Visual Studio C++
endif()


add_executable(DrillCLI CLI.cpp)
set_property(TARGET DrillCLI PROPERTY CXX_STANDARD 17)


include_directories(../Core)
include_directories(../Core/spdlog/include)

# add_custom_target(run
#     COMMAND DrillCLI
#     DEPENDS DrillCLI
#     WORKING_DIRECTORY ${CMAKE_PROJECT_DIR}
# )




add_subdirectory(../Core ${CMAKE_CURRENT_BINARY_DIR}/Core)

target_link_libraries(DrillCLI DrillCore)


if(UNIX AND NOT APPLE) 
    message(STATUS "Building for Linux")
 
    target_link_libraries(DrillCLI pthread)
endif()