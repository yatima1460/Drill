cmake_minimum_required(VERSION 2.8.9)
project (DrillGTK CXX)
add_executable(DrillGTK Main.cpp)

include_directories(../Core)


add_custom_target(run
    COMMAND DrillGTK
    DEPENDS DrillGTK
    WORKING_DIRECTORY ${CMAKE_PROJECT_DIR}
)



FIND_PACKAGE(PkgConfig REQUIRED)
PKG_CHECK_MODULES(GTK3 REQUIRED gtk+-3.0)

# Setup CMake to use GTK+, tell the compiler where to look for headers
# and to the linker where to look for libraries
INCLUDE_DIRECTORIES(${GTK3_INCLUDE_DIRS})
LINK_DIRECTORIES(${GTK3_LIBRARY_DIRS})

# Add other flags to the compiler
ADD_DEFINITIONS(${GTK3_CFLAGS_OTHER})


add_subdirectory(../Core ${CMAKE_CURRENT_BINARY_DIR}/Core)

target_link_libraries(DrillGTK DrillCore)


if(UNIX AND NOT APPLE) 
    message(STATUS "Linux")
 
    target_link_libraries(DrillGTK pthread)

    TARGET_LINK_LIBRARIES(DrillGTK ${GTK3_LIBRARIES})

endif()


