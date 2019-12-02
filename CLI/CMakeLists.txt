cmake_minimum_required(VERSION 2.8.9)
project (DrillCLI CXX)
add_executable(DrillCLI CLI.cpp)

include_directories(../Core)


add_custom_target(run
    COMMAND DrillCLI
    DEPENDS DrillCLI
    WORKING_DIRECTORY ${CMAKE_PROJECT_DIR}
)



# if (CMAKE_BUILD_TYPE MATCHES Release)
#     add_definitions(-DNDEBUG)
# endif()


add_subdirectory(../Core ${CMAKE_CURRENT_BINARY_DIR}/Core)

target_link_libraries(DrillCLI DrillCore)


if(UNIX AND NOT APPLE) 
    message(STATUS "Linux")
 
    target_link_libraries(DrillCLI pthread)
endif()