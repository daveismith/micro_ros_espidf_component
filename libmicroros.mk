EXTENSIONS_DIR = $(shell pwd)
UROS_DIR = $(EXTENSIONS_DIR)/micro_ros_src
BUILD_DIR ?= $(EXTENSIONS_DIR)/build

DEBUG ?= 0

ifeq ($(DEBUG), 1)
	BUILD_TYPE = Debug
else
	BUILD_TYPE = Release
endif

# Interpreter for colcon and the rosidl generators (IDF's venv, see README).
MICROROS_PYTHON ?= python3

# zenoh middleware: sources come from this component's submodules, not a clone.
# They are symlinked into the colcon workspace so an edit in deps/ is what the
# next colcon run compiles (remove micro_ros_src/install/.colcon_built to force one).
ZENOH_PICO_SRC ?= $(EXTENSIONS_DIR)/deps/zenoh-pico
RMW_ZENOH_PICO_SRC ?= $(EXTENSIONS_DIR)/deps/rmw_zenoh_pico/rmw_zenoh_pico

# CMake 4 refuses cmake_minimum_required() below 3.5, which older ROS
# packages still declare; this lets them configure.
COMMON_CMAKE_ARGS = -DPython3_EXECUTABLE=$(MICROROS_PYTHON) -DCMAKE_POLICY_VERSION_MINIMUM=3.5

# The Python minor version, for the workspace's site-packages path below.
PYVER := $(shell $(MICROROS_PYTHON) -c 'import sys; print("%d.%d" % sys.version_info[:2])')

all: $(EXTENSIONS_DIR)/libmicroros.a

clean:
	rm -rf $(EXTENSIONS_DIR)/libmicroros.a; \
	rm -rf $(EXTENSIONS_DIR)/include; \
	rm -rf $(EXTENSIONS_DIR)/esp32_toolchain.cmake; \
	rm -rf $(EXTENSIONS_DIR)/micro_ros_dev; \
	rm -rf $(EXTENSIONS_DIR)/micro_ros_src;

$(EXTENSIONS_DIR)/esp32_toolchain.cmake: $(EXTENSIONS_DIR)/esp32_toolchain.cmake.in
	rm -f $(EXTENSIONS_DIR)/esp32_toolchain.cmake; \
	cat $(EXTENSIONS_DIR)/esp32_toolchain.cmake.in | \
		sed "s/@CMAKE_C_COMPILER@/$(subst /,\/,$(X_CC))/g" | \
		sed "s/@CMAKE_CXX_COMPILER@/$(subst /,\/,$(X_CXX))/g" | \
		sed "s/@IDF_TARGET@/$(subst /,\/,$(IDF_TARGET))/g" | \
		sed "s/@IDF_PATH@/$(subst /,\/,$(IDF_PATH))/g" | \
		sed "s/@BUILD_CONFIG_DIR@/$(subst /,\/,$(BUILD_DIR)/config)/g" \
		> $(EXTENSIONS_DIR)/esp32_toolchain.cmake

$(EXTENSIONS_DIR)/micro_ros_dev/install:
	rm -rf micro_ros_dev; \
	mkdir micro_ros_dev; cd micro_ros_dev; \
	git clone -b jazzy https://github.com/ament/ament_cmake src/ament_cmake; \
	git clone -b jazzy https://github.com/ament/ament_lint src/ament_lint; \
	git clone -b jazzy https://github.com/ament/ament_package src/ament_package; \
	git clone -b jazzy https://github.com/ament/googletest src/googletest; \
	git clone -b jazzy https://github.com/ros2/ament_cmake_ros src/ament_cmake_ros; \
	git clone -b jazzy https://github.com/ament/ament_index src/ament_index; \
	colcon build --cmake-args -DBUILD_TESTING=OFF -DCMAKE_C_COMPILER=cc -DCMAKE_CXX_COMPILER=c++ $(COMMON_CMAKE_ARGS);

$(EXTENSIONS_DIR)/micro_ros_src/src:
	rm -rf micro_ros_src; \
	mkdir micro_ros_src; cd micro_ros_src; \
	if [ "$(MIDDLEWARE)" = "embeddedrtps" ]; then \
		git clone -b main https://github.com/micro-ROS/embeddedRTPS src/embeddedRTPS; \
		git clone -b main https://github.com/micro-ROS/rmw_embeddedrtps src/rmw_embeddedrtps; \
	elif [ "$(MIDDLEWARE)" = "zenohpico" ]; then \
		mkdir -p src; \
		ln -s $(ZENOH_PICO_SRC) src/zenoh-pico || exit 1; \
		ln -s $(RMW_ZENOH_PICO_SRC) src/rmw_zenoh_pico || exit 1; \
	else \
		git clone -b ros2 https://github.com/eProsima/Micro-XRCE-DDS-Client src/Micro-XRCE-DDS-Client; \
		git clone -b jazzy https://github.com/micro-ROS/rmw_microxrcedds src/rmw_microxrcedds; \
	fi; \
	git clone -b ros2 https://github.com/eProsima/micro-CDR src/micro-CDR; \
	git clone -b jazzy https://github.com/micro-ROS/rcl src/rcl; \
	git clone -b jazzy https://github.com/ros2/rclc src/rclc; \
	git clone -b jazzy https://github.com/micro-ROS/rcutils src/rcutils; \
	git clone -b jazzy https://github.com/micro-ROS/micro_ros_msgs src/micro_ros_msgs; \
	git clone -b jazzy https://github.com/micro-ROS/rosidl_typesupport src/rosidl_typesupport; \
	git clone -b jazzy https://github.com/micro-ROS/rosidl_typesupport_microxrcedds src/rosidl_typesupport_microxrcedds; \
	git clone -b jazzy https://github.com/ros2/rosidl src/rosidl; \
	git clone -b jazzy https://github.com/ros2/rosidl_dynamic_typesupport src/rosidl_dynamic_typesupport; \
	git clone -b jazzy https://github.com/ros2/rmw src/rmw; \
	git clone -b jazzy https://github.com/ros2/rcl_interfaces src/rcl_interfaces; \
	git clone -b jazzy https://github.com/ros2/rosidl_defaults src/rosidl_defaults; \
	git clone -b jazzy https://github.com/ros2/unique_identifier_msgs src/unique_identifier_msgs; \
	git clone -b jazzy https://github.com/ros2/common_interfaces src/common_interfaces; \
	git clone -b jazzy https://github.com/ros2/example_interfaces src/example_interfaces; \
	git clone -b jazzy https://github.com/ros2/test_interface_files src/test_interface_files; \
	git clone -b jazzy https://github.com/ros2/rmw_implementation src/rmw_implementation; \
	git clone -b jazzy https://github.com/ros2/rcl_logging src/rcl_logging; \
	git clone -b jazzy https://github.com/ros2/ros2_tracing src/ros2_tracing; \
	git clone -b jazzy https://github.com/micro-ROS/micro_ros_utilities src/micro_ros_utilities; \
	git clone -b jazzy https://github.com/ros2/rosidl_core src/rosidl_core; \
    touch src/rosidl/rosidl_typesupport_introspection_cpp/COLCON_IGNORE; \
    touch src/rcl_logging/rcl_logging_log4cxx/COLCON_IGNORE; \
    touch src/rcl_logging/rcl_logging_spdlog/COLCON_IGNORE; \
    touch src/rclc/rclc_examples/COLCON_IGNORE; \
	touch src/rcl/rcl_yaml_param_parser/COLCON_IGNORE; \
	touch src/ros2_tracing/test_tracetools/COLCON_IGNORE; \
	touch src/ros2_tracing/lttngpy/COLCON_IGNORE; \
	if [ "$(MIDDLEWARE)" = "zenohpico" ]; then \
		for p in visualization_msgs stereo_msgs trajectory_msgs shape_msgs nav_msgs diagnostic_msgs actionlib_msgs; do \
			touch src/common_interfaces/$$p/COLCON_IGNORE; \
		done; \
	fi; \
	cp -rfL $(EXTRA_ROS_PACKAGES) src/extra_packages || :; \
	test -f src/extra_packages/extra_packages.repos && cd src/extra_packages && vcs import --input extra_packages.repos || :;


# A stamp file rather than the install directory itself: colcon creates
# install/ as soon as the first package lands, so a partial build would
# otherwise satisfy the target and the next make would archive an incomplete
# workspace without rerunning colcon.
$(UROS_DIR)/install/.colcon_built: $(EXTENSIONS_DIR)/esp32_toolchain.cmake $(EXTENSIONS_DIR)/micro_ros_dev/install $(EXTENSIONS_DIR)/micro_ros_src/src
	cd $(UROS_DIR); \
	unset AMENT_PREFIX_PATH; \
	PATH="$(subst /opt/ros/$(ROS_DISTRO)/bin,,$(PATH))"; \
	. ../micro_ros_dev/install/local_setup.sh; \
	export AMENT_PREFIX_PATH="$(UROS_DIR)/install$${AMENT_PREFIX_PATH:+:$$AMENT_PREFIX_PATH}"; \
	export CMAKE_PREFIX_PATH="$(UROS_DIR)/install$${CMAKE_PREFIX_PATH:+:$$CMAKE_PREFIX_PATH}"; \
	export PYTHONPATH="$(UROS_DIR)/install/lib/python$(PYVER)/site-packages$${PYTHONPATH:+:$$PYTHONPATH}"; \
	if [ "$(MIDDLEWARE)" = "zenohpico" ]; then export RMW_IMPLEMENTATION=rmw_zenoh_pico; fi; \
	colcon build \
		--merge-install \
		--packages-ignore-regex=.*_cpp \
		--metas $(EXTENSIONS_DIR)/colcon.meta $(APP_COLCON_META) \
		--cmake-args \
		"--no-warn-unused-cli" \
		-DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=OFF \
		-DTHIRDPARTY=ON \
		-DBUILD_SHARED_LIBS=OFF \
		-DBUILD_TESTING=OFF \
		-DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
		-DCMAKE_TOOLCHAIN_FILE=$(EXTENSIONS_DIR)/esp32_toolchain.cmake \
		-DCMAKE_VERBOSE_MAKEFILE=OFF \
        -DIDF_INCLUDES='${IDF_INCLUDES}' \
		-DCMAKE_C_STANDARD=$(C_STANDARD) \
		-DUCLIENT_C_STANDARD=$(C_STANDARD) \
		$(COMMON_CMAKE_ARGS) \
	&& touch $(UROS_DIR)/install/.colcon_built;

# libzenohpico.a is not extracted like the others: it holds ~27 members with
# the same basename (tcp.c.obj, system.c.obj, ...) from different directories,
# and extracting into one folder would silently keep only the last of each.
# It is merged whole with an ar MRI script instead; duplicate member names
# inside one archive are fine for the linker.
$(EXTENSIONS_DIR)/libmicroros.a: $(UROS_DIR)/install/.colcon_built
	mkdir -p $(UROS_DIR)/libmicroros; cd $(UROS_DIR)/libmicroros; \
	for file in $$(find $(UROS_DIR)/install/lib/ -name '*.a' ! -name 'libzenohpico.a'); do \
		folder=$$(echo $$file | sed -E "s/(.+)\/(.+).a/\2/"); \
		mkdir -p $$folder; cd $$folder; $(X_AR) x $$file; \
		for f in *; do \
			mv $$f ../$$folder-$$f; \
		done; \
		cd ..; rm -rf $$folder; \
	done ; \
	$(X_AR) rc -s libmicroros.a *.obj; \
	if [ -f $(UROS_DIR)/install/lib/libzenohpico.a ]; then \
		printf 'open libmicroros.a\naddlib %s\nsave\nend\n' $(UROS_DIR)/install/lib/libzenohpico.a | $(X_AR) -M; \
		$(X_AR) -s libmicroros.a; \
	fi; \
	cp libmicroros.a $(EXTENSIONS_DIR); \
	cd ..; rm -rf libmicroros; \
	rm -rf $(EXTENSIONS_DIR)/include; \
	cp -R $(UROS_DIR)/install/include $(EXTENSIONS_DIR)/include;
