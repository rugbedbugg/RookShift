CXX ?= g++
CXXFLAGS := -std=c++17 -O2 -Wall -Wextra -Isrc

.PHONY: all demo test tool clean

all: demo test tool

demo: chess960_demo.exe
test: chess960_tests.exe chess960_message_tests.exe
tool: generate_positions_mem.exe

chess960_demo.exe: src/chess960_demo.cpp src/chess960.hpp src/chess960_message.hpp
	$(CXX) $(CXXFLAGS) src/chess960_demo.cpp -o chess960_demo.exe

chess960_tests.exe: tests/chess960_tests.cpp src/chess960.hpp
	$(CXX) $(CXXFLAGS) tests/chess960_tests.cpp -o chess960_tests.exe

chess960_message_tests.exe: tests/chess960_message_tests.cpp src/chess960_message.hpp
	$(CXX) $(CXXFLAGS) tests/chess960_message_tests.cpp -o chess960_message_tests.exe

generate_positions_mem.exe: tools/generate_positions_mem.cpp src/chess960.hpp
	$(CXX) $(CXXFLAGS) tools/generate_positions_mem.cpp -o generate_positions_mem.exe

clean:
ifeq ($(OS),Windows_NT)
	-del /Q chess960_demo.exe chess960_tests.exe chess960_message_tests.exe generate_positions_mem.exe 2>NUL
else
	rm -f chess960_demo.exe chess960_tests.exe chess960_message_tests.exe generate_positions_mem.exe
endif
