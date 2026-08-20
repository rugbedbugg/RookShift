// Regenerates a Chess960 positions-memory file for future hardware use:
// one line per seed (0..959), each a 16-hex-digit uint64_t produced by
// pack_board (see chess960.hpp for the bit layout), a real board encoding
// rather than a hash of the FEN. Output goes to data/chess960_positions.mem
// by default; this does not touch old/testing/chess960_positions.mem.
#include "../src/chess960.hpp"

#include <cstdio>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>

int main(int argc, char** argv) {
    std::string out_path = (argc >= 2) ? argv[1] : "data/chess960_positions.mem";

    std::ofstream out(out_path);
    if (!out) {
        std::cerr << "Error: could not open '" << out_path << "' for writing\n";
        return 1;
    }

    for (int seed = 0; seed < 960; ++seed) {
        uint64_t packed = chess960::pack_board(chess960::generate_position(seed));
        out << std::hex << std::uppercase << std::setw(16) << std::setfill('0') << packed << "\n";
    }

    std::cout << "Wrote 960 positions to " << out_path << "\n";
    return 0;
}
