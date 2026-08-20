// Chess960 position generator CLI.
//
// Usage:
//   chess960_demo --seed N        Print the position for seed N (0..959)
//   chess960_demo --random        Print the position for a random seed
//   chess960_demo --decode RNBQKBNR   Print the seed for a given back rank
//   chess960_demo --all           Print all 960 positions
//   chess960_demo --encode-message "text"     Pack text into a Chess960 seed sequence
//   chess960_demo --decode-message <tok...>   Recover text from seeds or back ranks
//   chess960_demo                 Same as --random
#include "chess960.hpp"
#include "chess960_message.hpp"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <iostream>
#include <optional>
#include <random>
#include <string>
#include <vector>

namespace {

void print_position(int seed) {
    chess960::Position pos = chess960::generate_position(seed);
    std::cout << "Seed:       " << seed << "\n";
    std::cout << "Back rank:  " << chess960::to_backrank_string(pos) << "\n";
    std::cout << "FEN:        " << chess960::to_fen(pos) << "\n";
    std::cout << "Packed hex: 0x" << std::hex << chess960::pack_board(pos) << std::dec << "\n";
}

std::optional<chess960::Position> parse_backrank(const std::string& backrank) {
    if (backrank.size() != 8) return std::nullopt;
    chess960::Position pos{};
    for (int i = 0; i < 8; ++i) {
        switch (std::toupper(static_cast<unsigned char>(backrank[i]))) {
            case 'R': pos[i] = chess960::Piece::Rook;   break;
            case 'N': pos[i] = chess960::Piece::Knight; break;
            case 'B': pos[i] = chess960::Piece::Bishop; break;
            case 'Q': pos[i] = chess960::Piece::Queen;  break;
            case 'K': pos[i] = chess960::Piece::King;   break;
            default: return std::nullopt;
        }
    }
    return pos;
}

int decode(const std::string& backrank) {
    auto pos = parse_backrank(backrank);
    if (!pos) {
        std::cerr << "Error: expected an 8-character back rank, e.g. RNBQKBNR\n";
        return 1;
    }
    auto seed = chess960::position_to_seed(*pos);
    if (!seed) {
        std::cerr << "Error: '" << backrank << "' is not a valid Chess960 starting position\n";
        return 1;
    }
    std::cout << "Back rank:  " << backrank << "\n";
    std::cout << "Seed:       " << *seed << "\n";
    return 0;
}

void print_all() {
    for (int seed = 0; seed < 960; ++seed) {
        std::cout << seed << "\t" << chess960::to_backrank_string(chess960::generate_position(seed)) << "\n";
    }
}

// A --decode-message token is either a bare seed number or an 8-letter back
// rank (as printed by --encode-message) -- accept either so a sequence
// transcribed from a diagram/photo and one copy-pasted from --encode-message
// both work.
std::optional<int> parse_seed_token(const std::string& token) {
    if (!token.empty() &&
        std::all_of(token.begin(), token.end(), [](unsigned char c) { return std::isdigit(c); })) {
        int seed = std::atoi(token.c_str());
        if (seed >= 0 && seed <= 959) return seed;
        return std::nullopt;
    }
    if (auto pos = parse_backrank(token)) {
        return chess960::position_to_seed(*pos);
    }
    return std::nullopt;
}

int encode_message_cmd(const std::string& message) {
    std::vector<int> seeds = chess960::encode_message(message);

    std::cout << "Message:    " << message << "\n";
    std::cout << "Positions:  " << seeds.size() << "\n\n";

    std::string seed_line;
    std::string backrank_line;
    for (size_t i = 0; i < seeds.size(); ++i) {
        chess960::Position pos = chess960::generate_position(seeds[i]);
        std::string backrank = chess960::to_backrank_string(pos);
        std::cout << "  #" << (i + 1) << "  seed=" << seeds[i] << "  " << backrank << "\n";
        if (i > 0) { seed_line += ' '; backrank_line += ' '; }
        seed_line += std::to_string(seeds[i]);
        backrank_line += backrank;
    }

    std::cout << "\nSeed sequence:      " << seed_line << "\n";
    std::cout << "Backrank sequence:  " << backrank_line << "\n";
    return 0;
}

int decode_message_cmd(const std::vector<std::string>& tokens) {
    std::vector<int> seeds;
    seeds.reserve(tokens.size());
    for (const std::string& token : tokens) {
        auto seed = parse_seed_token(token);
        if (!seed) {
            std::cerr << "Error: '" << token << "' is not a valid seed (0-959) or back rank\n";
            return 1;
        }
        seeds.push_back(*seed);
    }

    auto message = chess960::decode_message(seeds);
    if (!message) {
        std::cerr << "Error: this seed sequence is not a valid encoded message "
                      "(wrong length, or corrupted/tampered data)\n";
        return 1;
    }
    std::cout << "Decoded message: " << *message << "\n";
    return 0;
}

} // namespace

int main(int argc, char** argv) {
    if (argc >= 3 && std::strcmp(argv[1], "--seed") == 0) {
        int seed = std::atoi(argv[2]);
        if (seed < 0 || seed > 959) {
            std::cerr << "Error: seed must be in [0, 959]\n";
            return 1;
        }
        print_position(seed);
        return 0;
    }

    if (argc >= 3 && std::strcmp(argv[1], "--decode") == 0) {
        return decode(argv[2]);
    }

    if (argc >= 2 && std::strcmp(argv[1], "--all") == 0) {
        print_all();
        return 0;
    }

    if (argc >= 3 && std::strcmp(argv[1], "--encode-message") == 0) {
        return encode_message_cmd(argv[2]);
    }

    if (argc >= 3 && std::strcmp(argv[1], "--decode-message") == 0) {
        std::vector<std::string> tokens(argv + 2, argv + argc);
        return decode_message_cmd(tokens);
    }

    // Default and --random both fall through here.
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<int> dist(0, 959);
    print_position(dist(gen));
    return 0;
}
