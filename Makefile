CXX ?= g++
CXXFLAGS := -std=c++17 -O2 -Wall -Wextra -Isrc
BUILD_DIR := build

# Native Windows cmd has neither `mkdir -p` nor `rm`. Under MSYS2/MinGW, OS is
# still Windows_NT but MSYSTEM is set, so the POSIX branch applies there.
ifeq ($(OS)$(MSYSTEM),Windows_NT)
MKDIR_BUILD := if not exist "$(BUILD_DIR)" mkdir "$(BUILD_DIR)"
RM_BUILD := if exist "$(BUILD_DIR)" rmdir /S /Q "$(BUILD_DIR)"
else
MKDIR_BUILD := mkdir -p $(BUILD_DIR)
RM_BUILD := rm -rf $(BUILD_DIR)
endif

.PHONY: all demo test tool check clean

all: demo test tool

demo: $(BUILD_DIR)/chess960_demo.exe
test: $(BUILD_DIR)/chess960_tests.exe $(BUILD_DIR)/chess960_message_tests.exe
tool: $(BUILD_DIR)/generate_positions_mem.exe

$(BUILD_DIR):
	$(MKDIR_BUILD)

$(BUILD_DIR)/chess960_demo.exe: src/chess960_demo.cpp src/chess960.hpp src/chess960_message.hpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) src/chess960_demo.cpp -o $@

$(BUILD_DIR)/chess960_tests.exe: tests/chess960_tests.cpp src/chess960.hpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) tests/chess960_tests.cpp -o $@

$(BUILD_DIR)/chess960_message_tests.exe: tests/chess960_message_tests.cpp src/chess960_message.hpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) tests/chess960_message_tests.cpp -o $@

$(BUILD_DIR)/generate_positions_mem.exe: tools/generate_positions_mem.cpp src/chess960.hpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) tools/generate_positions_mem.cpp -o $@

check: test
	./$(BUILD_DIR)/chess960_tests.exe
	./$(BUILD_DIR)/chess960_message_tests.exe

clean:
	$(RM_BUILD)
