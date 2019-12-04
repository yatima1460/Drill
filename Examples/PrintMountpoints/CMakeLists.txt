cmake_minimum_required(VERSION 2.8.9)
project (Example CXX)
add_executable(Example main.cpp)

include_directories(../../Core)


add_custom_target(run
    COMMAND Example
    DEPENDS Example
    WORKING_DIRECTORY ${CMAKE_PROJECT_DIR}
)


add_subdirectory(../../Core ${CMAKE_CURRENT_BINARY_DIR}/Core)

target_link_libraries(Example DrillCore)
