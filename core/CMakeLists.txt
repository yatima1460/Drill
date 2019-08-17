cmake_minimum_required(VERSION 3.0.0)
set (CMAKE_C_STANDARD 11)

project(DrillCore VERSION 0.1.0)

# include(CTest)
# enable_testing()



# here we specify that the project is C language only, so the default
# C compiler on the system will be used
project(DrillCore C)


# include_directories("${CMAKE_CURRENT_SOURCE_DIR}")

file(GLOB drillcore_SRC "*.h" "*.c")

add_library(DrillCore ${drillcore_SRC})
set_target_properties(DrillCore PROPERTIES LINKER_LANGUAGE C)





set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})
include(CPack)


install(TARGETS DrillCore DESTINATION bin)