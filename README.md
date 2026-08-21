# RookShift

![GitHub last commit](https://img.shields.io/github/last-commit/rugbedbugg/RookShift?style=for-the-badge&labelColor=000000&color=9ccbfb)
![GitHub repo size](https://img.shields.io/github/repo-size/rugbedbugg/RookShift?style=for-the-badge&labelColor=000000&color=d3bfe6)
![Stars](https://img.shields.io/github/stars/rugbedbugg/RookShift?style=for-the-badge&labelColor=000000&color=9ccbfe6)  

A fully-kitted out Chess960 (Fischer Random Chess) position generator, encoder/decoder, message packer, built from scratch. Also includes a Verilog RTL implementation for hardware use.

This backs the IEEE paper on [FPGA-based Chess960 generation](https://doi.org/10.1109/SISIMPACT67725.2025.11439749) for steganography. Shoutout to my co-author Naman Goyal, who previously maintained the prototype code [here](https://github.com/NamanGoyalK/Chess960).

## Structure

- `src/`, `tests/`, `tools/` - C++17 core, no dependencies.
- `hdl/`, `sim/` - Verilog RTL and ModelSim testbench.

## Building

```sh
g++ -std=c++17 -O2 -Wall -Wextra -Isrc src/chess960_demo.cpp -o chess960_demo.exe
g++ -std=c++17 -O2 -Wall -Wextra -Isrc tests/chess960_tests.cpp -o chess960_tests.exe
g++ -std=c++17 -O2 -Wall -Wextra -Isrc tests/chess960_message_tests.cpp -o chess960_message_tests.exe
g++ -std=c++17 -O2 -Wall -Wextra -Isrc tools/generate_positions_mem.cpp -o generate_positions_mem.exe
```

Don't forget to use the `.exe` suffix on Windows machines, some compiler drivers won't add it for you.

Or use `make` (defaults to `g++`, override with `make CXX=clang++`):

```sh
make
```

## Usage

```sh
./chess960_demo.exe --seed 518
./chess960_demo.exe --random
./chess960_demo.exe --decode RNBQKBNR
./chess960_demo.exe --all
```

`src/chess960.hpp` implements the standard Scharnagl numbering scheme: a seed from 0-959 maps to one of the 960 valid starting positions and back. Also defines a 64-bit board encoding (8 squares, 3 bits each) for hardware use.

## Message encoding

```sh
./chess960_demo.exe --encode-message "Hello world"
./chess960_demo.exe --decode-message 93 690 813 793 352 154 589 70 547 193
```

`src/chess960_message.hpp` packs arbitrary bytes into a sequence of seeds: 6-byte chunks become 5 seeds each, PKCS7 padded. Uses close to the full 9.9-bit capacity per position instead of only ever touching seeds 0-255. `--decode-message` accepts seed numbers or back rank strings, and rejects malformed input.

## Testing

```sh
./chess960_tests.exe
./chess960_message_tests.exe
```

`chess960_tests` covers all 960 positions exhaustively. `chess960_message_tests` covers padding boundaries, non-ASCII bytes, and malformed input rejection.

## Hardware simulation

`hdl/` and `sim/` implement the generator in Verilog, matching the paper's architecture (input interface, control logic FSM, position generation logic, output interface, decoder) instead of the archived code's ROM lookup and linear search decoder. Verified in ModelSim Intel FPGA Starter Edition 20.1.

```sh
g++ -std=c++17 -O2 -Wall -Wextra -Isrc tools/generate_positions_mem.cpp -o generate_positions_mem.exe
mkdir -p data
./generate_positions_mem.exe

MODELSIM="/c/intelFPGA/20.1/modelsim_ase/win32aloem"
rm -rf work
"$MODELSIM/vlib" work
"$MODELSIM/vlog" +incdir+hdl hdl/chess960_position_generator.v hdl/chess960_input_interface.v hdl/chess960_control_logic.v hdl/chess960_output_interface.v hdl/chess960_decoder.v hdl/chess960_top.v sim/chess960_tb.v
"$MODELSIM/vsim" -c work.chess960_tb -do sim/run_sim.do
```

Results: 66/66 tests passed, fixed 6-cycle generate latency, fixed 1-cycle decode latency.

## Citation

```bibtex
@inproceedings{goyal2025chess960,
  title={Resource-Efficient FPGA Realization of Chess960 Position Generator for Future Covert Communication Systems},
  author={Goyal, Naman and Gogoi, Partha Pratim and Tripathi, Abhishek Narayan and Laskar, Naushad Manzoor},
  booktitle={2025 IEEE 1st International Conference on Smart Innovations in Systems, Infrastructure, Mechanical, Power, AI and Computing Technologies (SISIMPACT)},
  year={2025},
  publisher={IEEE},
  doi={10.1109/SISIMPACT67725.2025.11439749}
}
```

## License

Apache License 2.0
