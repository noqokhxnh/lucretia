cmake_minimum_required(VERSION 3.16)
project(lucretia_daemons VERSION 1.4.2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Optimization flags
add_compile_options(-O3 -pthread)

# Find Qt6 components
find_package(Qt6 REQUIRED COMPONENTS Core Network DBus Gui)

# Find SQLite3 & ZBar
find_package(PkgConfig REQUIRED)
pkg_check_modules(SQLITE3 REQUIRED sqlite3)
pkg_check_modules(ZBAR REQUIRED zbar)

# Source files for Primary Quickshell Daemon
set(DAEMON_SOURCES
    main.cpp
    core/ipc_server.cpp
    system/system_monitor.cpp
    system/file_watcher.cpp
    system/dbus_watcher.cpp
    system/weather_engine.cpp
    system/theme_manager.cpp
    music/music_manager.cpp
    focus/focus_tracker.cpp
    apps/app_indexer.cpp
    media/media_processor.cpp
    media/audio_spectrum.cpp
    services/service_manager.cpp
    clipboard/clipboard_manager.cpp
)

set(DAEMON_HEADERS
    core/ipc_server.hpp
    system/system_monitor.hpp
    system/file_watcher.hpp
    system/dbus_watcher.hpp
    system/weather_engine.hpp
    system/theme_manager.hpp
    music/music_manager.hpp
    focus/focus_tracker.hpp
    apps/app_indexer.hpp
    media/media_processor.hpp
    media/audio_spectrum.hpp
    services/service_manager.hpp
    clipboard/clipboard_manager.hpp
)

add_executable(qs_daemon ${DAEMON_SOURCES} ${DAEMON_HEADERS})

target_include_directories(qs_daemon PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${SQLITE3_INCLUDE_DIRS}
    ${ZBAR_INCLUDE_DIRS}
)

target_link_libraries(qs_daemon PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::DBus
    Qt6::Gui
    ${SQLITE3_LIBRARIES}
    ${ZBAR_LIBRARIES}
)

# Output qs_daemon binary to bin/quickshell/
set_target_properties(qs_daemon PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../bin/quickshell"
)

# Keycast Backend target
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/keycast_backend.cpp")
    add_executable(keycast_backend keycast_backend.cpp)
    target_link_libraries(keycast_backend PRIVATE Qt6::Core Qt6::Gui)
    set_target_properties(keycast_backend PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../bin"
    )
endif()
