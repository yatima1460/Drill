cmake_minimum_required (VERSION 3.0)

project(Drill)

# execute_process(COMMAND "dub -b build -c CLI" RESULT_VARIABLE dub_result OUTPUT_VARIABLE dub_var)
# message(STATUS "[${dub_result}]: ${dub_var}")

add_subdirectory(CoreCpp)
# add_subdirectory(CLICpp)

if (WIN32)
    add_subdirectory(Win32)
endif (WIN32)

if (UNIX)
    add_subdirectory(GTK)
endif (UNIX)
