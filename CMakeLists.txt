# Which uros_*_netif source is built follows the Kconfig network-interface
# choice ("None" builds no netif at all: the application owns its network).
# Sources may depend on CONFIG_*; REQUIRES may not (IDF expands requirements
# before the configuration is loaded), so the requirement list is static and
# the Ethernet driver is an optional requirement added below.
set(COMPONENT_SRC "")

if(CONFIG_MICRO_ROS_ESP_NETIF_ENET)
    list(APPEND COMPONENT_SRC "network_interfaces/uros_ethernet_netif.c")
elseif(CONFIG_MICRO_ROS_ESP_NETIF_WLAN)
    list(APPEND COMPONENT_SRC "network_interfaces/uros_wlan_netif.c")
endif()

# pthread: zenoh-pico's ESP-IDF system layer uses pthread mutexes and condition
# variables, and pthread is not one of IDF's common component requirements.
idf_component_register(SRCS ${COMPONENT_SRC}
                       INCLUDE_DIRS "network_interfaces"
                       REQUIRES nvs_flash esp_wifi lwip pthread esp_netif esp_event)

if(CONFIG_MICRO_ROS_ESP_NETIF_ENET)
    idf_component_optional_requires(PRIVATE esp_eth)
endif()

if(CMAKE_GENERATOR STREQUAL "Unix Makefiles")
set(submake "make")
else()
set(submake "make")
endif()

set(CMAKE_C_STANDARD 17)

set(APP_COLCON_META "${PROJECT_DIR}/app-colcon.meta")
if(NOT EXISTS "${APP_COLCON_META}")
set(APP_COLCON_META "")
endif()

set(EXTRA_ROS_PACKAGES "${PROJECT_DIR}/extra_ros_packages")
if(NOT EXISTS "${EXTRA_ROS_PACKAGES}")
set(EXTRA_ROS_PACKAGES "${COMPONENT_DIR}/extra_packages")
endif()

if(CONFIG_MICRO_ROS_ESP_ZENOH_PICO_MIDDLEWARE)
message(STATUS "Using zenoh-pico middleware (rmw_zenoh_pico)")
set(MIDDLEWARE "zenohpico")
elseif(CONFIG_MICRO_ROS_ESP_EMBEDDEDRTPS_MIDDLEWARE)
message(STATUS "Using embeddedRTPS middleware")
set(MIDDLEWARE "embeddedrtps")
else()
message(STATUS "Using Micro XRCE-DDS middleware")
set(MIDDLEWARE "microxrcedds")
endif()

# The zenoh stack is not cloned at build time: zenoh-pico and rmw_zenoh_pico are
# pinned submodules of this component (deps/), copied into the colcon workspace
# by libmicroros.mk. RMW_ZENOH_PICO_SRC is the package directory, not the repo
# root, which also holds examples and host Makefiles.
set(ZENOH_PICO_SRC "${COMPONENT_DIR}/deps/zenoh-pico")
set(RMW_ZENOH_PICO_SRC "${COMPONENT_DIR}/deps/rmw_zenoh_pico/rmw_zenoh_pico")

# The interpreter colcon and the rosidl generators run with: IDF's own Python
# environment, which is where the README says colcon, catkin_pkg, lark and empy
# must be installed.
idf_build_get_property(MICROROS_PYTHON PYTHON)
if(NOT MICROROS_PYTHON)
    set(MICROROS_PYTHON "python3")
endif()

# Create a list of packages to get includes
idf_build_get_property(PACKAGES BUILD_COMPONENTS)

# Add includes for each package
foreach(package ${PACKAGES})
    idf_component_get_property(${package}_dir ${package} COMPONENT_DIR)
    idf_component_get_property(${package}_includes ${package} INCLUDE_DIRS)
    list(TRANSFORM ${package}_includes PREPEND " -I${${package}_dir}/")
    string(REPLACE ";" "" ${package}_includes_string "${${package}_includes}")
endforeach()

# Workaround for https://github.com/ros2/rosidl/pull/739
string(APPEND IDF_INCLUDES "-I${COMPONENT_DIR}/include_override")

# Create a string with all packages with a for loop
foreach(package ${PACKAGES})
    string(APPEND IDF_INCLUDES "${${package}_includes_string}")
endforeach()

execute_process(
    WORKING_DIRECTORY ${COMPONENT_DIR}
    RESULT_VARIABLE libmicroros_ret
    COMMAND
        ${submake} -j -f libmicroros.mk
                X_CC=${CMAKE_C_COMPILER}
                X_AR=${CMAKE_AR}
                X_CXX=${CMAKE_CXX_COMPILER}
                C_STANDARD=${CMAKE_C_STANDARD}
                MIDDLEWARE=${MIDDLEWARE}
                BUILD_DIR=${CMAKE_BINARY_DIR}
                IDF_INCLUDES=${IDF_INCLUDES}
                IDF_PATH=${IDF_PATH}
                IDF_TARGET=${IDF_TARGET}
                APP_COLCON_META=${APP_COLCON_META}
                EXTRA_ROS_PACKAGES=${EXTRA_ROS_PACKAGES}
                ZENOH_PICO_SRC=${ZENOH_PICO_SRC}
                RMW_ZENOH_PICO_SRC=${RMW_ZENOH_PICO_SRC}
                MICROROS_PYTHON=${MICROROS_PYTHON}
)
if(libmicroros_ret AND NOT libmicroros_ret EQUAL 0)
  message(FATAL_ERROR "FAILED: ${libmicroros_ret}")
endif()

add_prebuilt_library(libmicroros-prebuilt ""
                     REQUIRES lwip pthread)

add_dependencies(libmicroros-prebuilt libmicroros_project)

set_target_properties(libmicroros-prebuilt PROPERTIES IMPORTED_LOCATION ${COMPONENT_DIR}/libmicroros.a)
target_include_directories(libmicroros-prebuilt INTERFACE ${COMPONENT_DIR}/include)

file(GLOB include_folders LIST_DIRECTORIES true CONFIGURE_DEPENDS ${COMPONENT_DIR}/include/*)
foreach(include_folder ${include_folders})
    if(IS_DIRECTORY ${include_folder})
        get_filename_component(folder_name ${include_folder} NAME)
        target_include_directories(libmicroros-prebuilt INTERFACE ${COMPONENT_DIR}/include/${folder_name})
    endif()
endforeach()

# What a consumer of these headers must define to see the same declarations
# the library was compiled with:
#  - ZENOH_ESPIDF selects zenoh-pico's platform header (task/mutex/socket
#    types); without it zenoh-pico.h stops at "#error Unknown platform".
#  - __STDC_WANT_LIB_EXT1__ is what the toolchain file sets for picolibc so
#    rcutils' error_handling.h, which asks for Annex K after other headers
#    already pulled in <string.h>, does not trip over missing __errno_t.
if(CONFIG_MICRO_ROS_ESP_ZENOH_PICO_MIDDLEWARE)
    target_compile_definitions(libmicroros-prebuilt INTERFACE ZENOH_ESPIDF)
endif()
if(CONFIG_LIBC_PICOLIBC)
    # -U first: IDF's esp_libc defines it to 0 project-wide for newlib
    # compatibility, and a plain redefinition would warn on every file.
    target_compile_options(libmicroros-prebuilt INTERFACE -U__STDC_WANT_LIB_EXT1__ -D__STDC_WANT_LIB_EXT1__=1)
endif()

add_dependencies(${COMPONENT_LIB} libmicroros-prebuilt)
target_link_libraries(${COMPONENT_LIB} INTERFACE libmicroros-prebuilt)

set_directory_properties( PROPERTIES ADDITIONAL_CLEAN_FILES
    "${COMPONENT_DIR}/include;${COMPONENT_DIR}/micro_ros_dev;${COMPONENT_DIR}/micro_ros_src;${COMPONENT_DIR}/esp32_toolchain.cmake" )

add_custom_target(clean-microros COMMAND ${submake} -f libmicroros.mk clean
                            WORKING_DIRECTORY ${COMPONENT_DIR})
