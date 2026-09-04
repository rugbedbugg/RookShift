# RookShift

![GitHub last commit](https://img.shields.io/github/last-commit/rugbedbugg/RookShift?style=for-the-badge&labelColor=000000)
![GitHub repo size](https://img.shields.io/github/repo-size/rugbedbugg/RookShift?style=for-the-badge&labelColor=000000)
![Stars](https://img.shields.io/github/stars/rugbedbugg/RookShift?style=for-the-badge&labelColor=000000)

A fully-kitted Chess960 (Fischer Random Chess) position generator, encoder/decoder, and message packer built from scratch in C++17. Includes a Verilog RTL implementation for FPGA deployment. Backs the IEEE paper on **FPGA-based Chess960 generation for steganography** (DOI: 10.1109/SISIMPACT67725.2025.11439749).

## Status

**Active** - core C++ library complete, Verilog RTL verified in ModelSim, message encoding/decoding functional.

## Features

| Feature | Description |
|---------|-------------|
| Scharnagl numbering | Bijective mapping: seed (0–959) ↔ 960 valid Chess960 starting positions |
| 64-bit board encoding | 8 squares × 3 bits each, designed for hardware efficiency |
| Message steganography | Packs arbitrary bytes into seed sequences (6-byte chunks → 5 seeds, PKCS#7 padding, ~9.9 bits/position) |
| Exhaustive test coverage | All 960 positions validated round-trip |
| Verilog RTL | Input interface, control logic FSM, position generator, output interface, decoder |
| Fixed latency | 6-cycle generate, 1-cycle decode (verified in simulation) |
| Zero dependencies | Standard library only |

## Tech Stack

| Component | Details |
|-----------|---------|
| C++17 | Core library, tests, tools - no external deps |
| Verilog | RTL + ModelSim testbenches (`hdl/`, `sim/`) |
| Build | Make (`make` or `make CXX=clang++`) |
| Simulation | ModelSim Intel FPGA Starter Edition 20.1 |

## Architecture

### C++ Core (`src/`, `tests/`, `tools/`)

| Component | Purpose |
|-----------|---------|
| `chess960.hpp` | Scharnagl encode/decode, 64-bit board representation |
| `chess960_message.hpp` | Byte → seed sequence packing/unpacking (steganography) |
| `chess960_demo.cpp` | CLI demo: generate, decode, encode/decode messages |
| `chess960_tests.cpp` | Exhaustive 960-position round-trip validation |
| `chess960_message_tests.cpp` | Padding, non-ASCII, malformed input tests |
| `generate_positions_mem.cpp` | Generates `data/chess960_positions.mem` for RTL simulation |

### Verilog RTL (`hdl/`, `sim/`)

| Module | Description |
|--------|-------------|
| `chess960_input_interface.v` | Seed input, start pulse, ready/valid handshake |
| `chess960_control_logic.v` | FSM controlling generation sequence |
| `chess960_position_generator.v` | Core combinational Scharnagl algorithm |
| `chess960_output_interface.v` | Back-rank output (8×3-bit), done pulse |
| `chess960_decoder.v` | Back-rank string → seed decode (1-cycle) |
| `chess960_top.v` | Top-level integration |
| `chess960_tb.v` | ModelSim testbench (66 tests) |

## Install / Build

### Prerequisites

| Requirement | Details |
|-------------|---------|
| C++17 compiler | GCC ≥ 7, Clang ≥ 5, MSVC ≥ 19.14 |
| Make | Optional, for `Makefile` |
| ModelSim | For RTL simulation (Intel FPGA Starter Edition 20.1 tested) |

### Build C++ Targets

```bash
make
# or manually:
g++ -std=c++17 -O2 -Wall -Wextra -Isrc src/chess960_demo.cpp -o build/chess960_demo.exe
g++ -std=c++17 -O2 -Wall -Wextra -Isrc tests/chess960_tests.cpp -o build/chess960_tests.exe
g++ -std=c++17 -O2 -Wall -Wextra -Isrc tests/chess960_message_tests.cpp -o build/chess960_message_tests.exe
g++ -std=c++17 -O2 -Wall -Wextra -Isrc tools/generate_positions_mem.cpp -o build/generate_positions_mem.exe
```

> Use `.exe` suffix on Windows; some compiler drivers won't add it automatically.

### RTL Simulation

```bash
# 1) Generate position memory file
./build/generate_positions_mem.exe
# Creates data/chess960_positions.mem

# 2) Compile & simulate in ModelSim
MODELSIM="/c/intelFPGA/20.1/modelsim_ase/win32aloem"  # adjust path
rm -rf work
"$MODELSIM/vlib" work
"$MODELSIM/vlog" +incdir+hdl hdl/*.v sim/chess960_tb.v
"$MODELSIM/vsim" -c work.chess960_tb -do sim/run_sim.do
```

Expected: **66/66 tests passed**, fixed 6-cycle generate latency, 1-cycle decode latency.

## Commands / Usage

### Position Generator Demo (`chess960_demo.exe`)

```bash
# Generate position from seed (0-959)
./build/chess960_demo.exe --seed 518

# Generate random position
./build/chess960_demo.exe --random

# Decode back-rank string to seed
./build/chess960_demo.exe --decode RNBQKBNR

# List all 960 positions
./build/chess960_demo.exe --all
```

### Message Steganography

```bash
# Encode message → seed sequence (6-byte chunks → 5 seeds, PKCS#7)
./build/chess960_demo.exe --encode-message "Hello world"

# Decode seed sequence → message
# Accepts space-separated seeds OR back-rank strings
./build/chess960_demo.exe --decode-message 93 690 813 793 352 154 589 70 547 193
```

| Flag | Description |
|------|-------------|
| `--seed <n>` | Generate position from seed (0–959) |
| `--random` | Generate cryptographically random position |
| `--decode <backrank>` | Decode 8-char back-rank to seed |
| `--all` | List all 960 positions (seed + back-rank) |
| `--encode-message <str>` | Pack string into seed sequence |
| `--decode-message <seeds...>` | Unpack seed sequence to string |

## Testing

```bash
# C++ tests
./build/chess960_tests.exe
# Exhaustive: all 960 positions encode↔decode correctly

./build/chess960_message_tests.exe
# Padding boundaries, non-ASCII bytes, malformed input rejection

# RTL simulation (ModelSim)
# 66/66 tests passed
```

## Project Structure

```
RookShift/
├── src/
│   ├── chess960.hpp              # Core: Scharnagl encode/decode, board encoding
│   ├── chess960_message.hpp      # Steganography: message ↔ seed sequence
│   └── chess960_demo.cpp         # CLI entry point
├── tests/
│   ├── chess960_tests.cpp        # 960-position exhaustive validation
│   └── chess960_message_tests.cpp # Message packing edge cases
├── tools/
│   └── generate_positions_mem.cpp # Generates .mem file for RTL sim
├── hdl/                          # Verilog RTL
│   ├── chess960_*.v              # 6 modules + top
│   └── chess960_defs.vh          # Shared constants
├── sim/                          # ModelSim testbenches
│   ├── *.v                       # 6 TBs + top TB
│   └── run_sim.do                # Simulation script
├── data/
│   └── chess960_positions.mem    # Position ROM for RTL (generated)
├── build/                        # Build output (gitignored)
├── work/                         # ModelSim work library (gitignored)
├── .github/workflows/c-cpp.yml   # CI: build + test on Ubuntu/macOS/Windows
├── Makefile
├── CITATION.CFF
├── LICENSE                       # Apache-2.0
├── NOTICE                        # Attribution for the upstream prototype
└── README.md
```

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

Apache License 2.0, see [LICENSE](LICENSE).

RookShift is a derivative work of the Chess960 FPGA prototype by Naman Goyal, which is itself Apache-2.0 licensed. Attribution for the original work is recorded in [NOTICE](NOTICE).

## Links

- **Repo:** https://github.com/rugbedbugg/RookShift
- **Paper:** https://doi.org/10.1109/SISIMPACT67725.2025.11439749
- **Issues:** https://github.com/rugbedbugg/RookShift/issues
- **Derived from (Naman Goyal's prototype):** https://github.com/NamanGoyalK/Chess960