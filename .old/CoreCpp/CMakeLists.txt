cmake_minimum_required (VERSION 2.8.11)


set (CMAKE_CXX_STANDARD 17)

project(DrillCore)

file( GLOB SOURCE_FILES Source/*.cpp )

include_directories(Include)

add_library(DrillCore STATIC ${SOURCE_FILES})



