// Exhaustive self-consistency test suite for chess960.hpp. No external test
// framework or reference library (python-chess) -- correctness rests on a
// closure argument: the algorithm's own domain math gives 4*4*6*10 = 960
// exactly, which is the independently, publicly known total count of valid
// Chess960 positions (it's the reason the variant is named "Chess960"). If
// the implementation produces 960 pairwise-distinct outputs that all satisfy
// the Chess960 constraints, that set must be exactly the full valid set, and
// the seed<->position map must be a bijection onto it.
#include "../src/chess960.hpp"

#include <iostream>
#include <set>
#include <string>

namespace {

int g_checks = 0;
int g_failures = 0;

void check(bool condition, const std::string& message) {
    ++g_checks;
    if (!condition) {
        ++g_failures;
        std::cerr << "FAIL: " << message << "\n";
    }
}

} // namespace

int main() {
    using namespace chess960;

    // 1. Bijectivity: decoding what we generated recovers the same seed.
    // 3. Constraints: every generated position is independently valid.
    // 5. Round-trip: packing and unpacking a board recovers the same board.
    std::set<std::string> seen_backranks;
    for (int seed = 0; seed < 960; ++seed) {
        Position pos = generate_position(seed);

        check(is_valid_chess960(pos), "seed " + std::to_string(seed) + " did not produce a valid Chess960 position");

        auto recovered_seed = position_to_seed(pos);
        check(recovered_seed.has_value() && *recovered_seed == seed,
              "seed " + std::to_string(seed) + " did not round-trip through position_to_seed");

        uint64_t packed = pack_board(pos);
        auto unpacked = unpack_board(packed);
        check(unpacked.has_value() && *unpacked == pos,
              "seed " + std::to_string(seed) + " did not round-trip through pack_board/unpack_board");

        seen_backranks.insert(to_backrank_string(pos));
    }

    // 2. Uniqueness: all 960 generated positions are pairwise distinct.
    check(seen_backranks.size() == 960, "expected 960 distinct positions, got " + std::to_string(seen_backranks.size()));

    // 4. Known checkpoints.
    check(to_backrank_string(generate_position(518)) == "RNBQKBNR",
          "seed 518 should be the orthodox starting position RNBQKBNR");
    check(to_backrank_string(generate_position(0)) == "BBQNNRKR",
          "seed 0 should be BBQNNRKR");
    check(to_backrank_string(generate_position(959)) == "RKRNNQBB",
          "seed 959 should be RKRNNQBB");

    // 6. Decoder robustness: invalid inputs must be rejected, not misread.
    auto make = [](std::initializer_list<Piece> pieces) {
        Position pos{};
        std::copy(pieces.begin(), pieces.end(), pos.begin());
        return pos;
    };

    // Bishops on the same color (both dark squares: 0 and 2).
    Position same_color_bishops = make({Piece::Bishop, Piece::Queen, Piece::Bishop, Piece::Knight,
                                         Piece::Knight, Piece::Rook, Piece::King, Piece::Rook});
    check(!position_to_seed(same_color_bishops).has_value(),
          "same-color bishops should be rejected");

    // King not between the rooks (king at 0, rooks at 4 and 7).
    Position king_outside_rooks = make({Piece::King, Piece::Bishop, Piece::Queen, Piece::Knight,
                                         Piece::Rook, Piece::Knight, Piece::Bishop, Piece::Rook});
    check(!position_to_seed(king_outside_rooks).has_value(),
          "king outside the rooks should be rejected");

    // Wrong piece multiset (two queens, no knights).
    Position wrong_multiset = make({Piece::Rook, Piece::Bishop, Piece::Queen, Piece::Queen,
                                     Piece::King, Piece::Bishop, Piece::Rook, Piece::Rook});
    check(!position_to_seed(wrong_multiset).has_value(),
          "wrong piece multiset should be rejected");

    // Garbage bit patterns for unpack_board: reserved high bits set, and an
    // invalid 3-bit piece code (0 = None) in the low bits.
    check(!unpack_board(0xFFFFFFFFFFFFFFFFULL).has_value(), "all-ones should be rejected");
    check(!unpack_board(0ULL).has_value(), "all-zero (every square None) should be rejected");
    check(!unpack_board(pack_board(generate_position(0)) | (1ULL << 24)).has_value(),
          "a set reserved bit should be rejected");

    std::cout << g_checks << " checks run, " << g_failures << " failures.\n";
    if (g_failures == 0) {
        std::cout << "All Chess960 self-consistency checks passed (960/960).\n";
    }
    return g_failures == 0 ? 0 : 1;
}
