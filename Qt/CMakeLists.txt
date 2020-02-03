cmake_minimum_required(VERSION 3.1.0)

project(DrillQt)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

if(CMAKE_VERSION VERSION_LESS "3.7.0")
    set(CMAKE_INCLUDE_CURRENT_DIR ON)
endif()

find_package(Qt5 COMPONENTS Core REQUIRED)
find_package(Qt5 COMPONENTS Widgets REQUIRED)

add_executable(DrillQt
    # mainwindow.ui
    drillqt.ui
    mainwindow.cpp
    # main.cpp
    # resources.qrc
)

target_link_libraries(DrillQt Qt5::Core)
target_link_libraries(DrillQt Qt5::Widgets)


