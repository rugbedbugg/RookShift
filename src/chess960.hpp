// Self-contained Chess960 (Fischer Random) position generator.
//
// Implements the standard Scharnagl numbering scheme mapping a seed in
// [0, 959] to one of the 960 valid Chess960 starting back-rank
// arrangements, and its inverse. No external dependencies.
#pragma once

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdint>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>

namespace chess960 {

enum class Piece : uint8_t {
    None   = 0,
    Rook   = 1,
    Knight = 2,
    Bishop = 3,
    Queen  = 4,
    King   = 5,
};

// Back-rank arrangement, index 0..7 = file a..h.
using Position = std::array<Piece, 8>;

// Square 0 (a1) is a dark square, so parity of the index gives its color.
constexpr bool is_light_square(int square) { return (square % 2) == 1; }

inline char piece_to_char(Piece p) {
    switch (p) {
        case Piece::Rook:   return 'R';
        case Piece::Knight: return 'N';
        case Piece::Bishop: return 'B';
        case Piece::Queen:  return 'Q';
        case Piece::King:   return 'K';
        default:            return '?';
    }
}

// Lexicographic "choose 2 of 5" table: kKnightPairs[i] gives the pair of
// 0-indexed slots (into whatever 5 squares remain after bishops/queen are
// placed) that the knights occupy for a given remainder value 0..9.
constexpr std::array<std::pair<int, int>, 10> kKnightPairs = {{
    {0, 1}, {0, 2}, {0, 3}, {0, 4},
    {1, 2}, {1, 3}, {1, 4},
    {2, 3}, {2, 4},
    {3, 4},
}};

// Generates the Chess960 position for the given seed (0..959) using the
// standard Scharnagl numbering scheme: seed decomposes via successive
// divmod by 4, 4, 6 (4*4*6*10 == 960, an exact closure) into independent
// choices for the light/dark bishops, the queen, and the knight pair; the
// three squares left over are always taken in ascending order and assigned
// Rook, King, Rook, which is what guarantees the king ends up strictly
// between the rooks.
inline Position generate_position(int seed) {
    if (seed < 0 || seed > 959) {
        throw std::out_of_range("chess960 seed must be in [0, 959]");
    }

    int n = seed;
    int r1 = n % 4; n /= 4;
    int r2 = n % 4; n /= 4;
    int r3 = n % 6; n /= 6;
    int n4 = n; // remaining value, already in [0, 9]

    Position pos{};
    pos.fill(Piece::None);

    pos[2 * r1 + 1] = Piece::Bishop; // light-squared bishop
    pos[2 * r2]     = Piece::Bishop; // dark-squared bishop

    std::array<int, 6> vacant6{};
    for (int sq = 0, idx = 0; sq < 8; ++sq) {
        if (pos[sq] == Piece::None) vacant6[idx++] = sq;
    }
    pos[vacant6[r3]] = Piece::Queen;

    std::array<int, 5> vacant5{};
    for (int sq = 0, idx = 0; sq < 8; ++sq) {
        if (pos[sq] == Piece::None) vacant5[idx++] = sq;
    }
    auto [k1, k2] = kKnightPairs[n4];
    pos[vacant5[k1]] = Piece::Knight;
    pos[vacant5[k2]] = Piece::Knight;

    std::array<int, 3> vacant3{};
    for (int sq = 0, idx = 0; sq < 8; ++sq) {
        if (pos[sq] == Piece::None) vacant3[idx++] = sq;
    }
    pos[vacant3[0]] = Piece::Rook;
    pos[vacant3[1]] = Piece::King;
    pos[vacant3[2]] = Piece::Rook;

    return pos;
}

// Independently checks Chess960 legality directly against the raw board
// (piece multiset, bishop colors, king-between-rooks) without relying on
// how the position was produced. Used both to validate arbitrary/untrusted
// input and as a non-circular correctness check on generate_position.
inline bool is_valid_chess960(const Position& pos) {
    int counts[6] = {0, 0, 0, 0, 0, 0};
    for (Piece p : pos) {
        if (p == Piece::None) return false;
        counts[static_cast<int>(p)]++;
    }
    if (counts[static_cast<int>(Piece::Rook)]   != 2) return false;
    if (counts[static_cast<int>(Piece::Knight)] != 2) return false;
    if (counts[static_cast<int>(Piece::Bishop)] != 2) return false;
    if (counts[static_cast<int>(Piece::Queen)]  != 1) return false;
    if (counts[static_cast<int>(Piece::King)]   != 1) return false;

    int bishop_sq[2], bi = 0;
    for (int sq = 0; sq < 8; ++sq) {
        if (pos[sq] == Piece::Bishop) bishop_sq[bi++] = sq;
    }
    if (is_light_square(bishop_sq[0]) == is_light_square(bishop_sq[1])) return false;

    int rook_sq[2], ri = 0, king_sq = -1;
    for (int sq = 0; sq < 8; ++sq) {
        if (pos[sq] == Piece::Rook) rook_sq[ri++] = sq;
        if (pos[sq] == Piece::King) king_sq = sq;
    }
    int lo = std::min(rook_sq[0], rook_sq[1]);
    int hi = std::max(rook_sq[0], rook_sq[1]);
    if (!(lo < king_sq && king_sq < hi)) return false;

    return true;
}

// Inverse of generate_position: recovers the seed from a board by undoing
// the same divmod decomposition. Returns std::nullopt for anything that
// isn't a valid Chess960 position, rather than guessing.
inline std::optional<int> position_to_seed(const Position& pos) {
    if (!is_valid_chess960(pos)) return std::nullopt;

    int bishop_sq[2], bi = 0;
    for (int sq = 0; sq < 8; ++sq) {
        if (pos[sq] == Piece::Bishop) bishop_sq[bi++] = sq;
    }
    int light_sq = is_light_square(bishop_sq[0]) ? bishop_sq[0] : bishop_sq[1];
    int dark_sq  = is_light_square(bishop_sq[0]) ? bishop_sq[1] : bishop_sq[0];
    int r1 = (light_sq - 1) / 2;
    int r2 = dark_sq / 2;

    std::array<int, 6> vacant6{};
    for (int sq = 0, idx = 0; sq < 8; ++sq) {
        if (pos[sq] != Piece::Bishop) vacant6[idx++] = sq;
    }
    int queen_sq = -1;
    for (int sq = 0; sq < 8; ++sq) {
        if (pos[sq] == Piece::Queen) queen_sq = sq;
    }
    int r3 = static_cast<int>(std::find(vacant6.begin(), vacant6.end(), queen_sq) - vacant6.begin());

    std::array<int, 5> vacant5{};
    for (int sq = 0, idx = 0; sq < 8; ++sq) {
        if (pos[sq] != Piece::Bishop && pos[sq] != Piece::Queen) vacant5[idx++] = sq;
    }
    int knight_sq[2], ki = 0;
    for (int sq = 0; sq < 8; ++sq) {
        if (pos[sq] == Piece::Knight) knight_sq[ki++] = sq;
    }
    int k1 = static_cast<int>(std::find(vacant5.begin(), vacant5.end(), knight_sq[0]) - vacant5.begin());
    int k2 = static_cast<int>(std::find(vacant5.begin(), vacant5.end(), knight_sq[1]) - vacant5.begin());
    if (k1 > k2) std::swap(k1, k2);

    int n4 = -1;
    for (int i = 0; i < 10; ++i) {
        if (kKnightPairs[i].first == k1 && kKnightPairs[i].second == k2) {
            n4 = i;
            break;
        }
    }
    if (n4 < 0) return std::nullopt;

    return ((n4 * 6 + r3) * 4 + r2) * 4 + r1;
}

// Packs a position into the low 24 bits of a uint64_t: 8 squares x 3 bits
// each, square i in bits [3i+2:3i], piece codes matching the Piece enum
// (1=Rook 2=Knight 3=Bishop 4=Queen 5=King; 0/6/7 unused). Bits [63:24] are
// reserved and always zero. This encodes board content only -- no seed bits
// -- so a future hardware decoder built against it does real content-based
// matching rather than just reading a seed back out.
inline uint64_t pack_board(const Position& pos) {
    uint64_t bits = 0;
    for (int sq = 0; sq < 8; ++sq) {
        bits |= (static_cast<uint64_t>(pos[sq]) & 0x7ULL) << (3 * sq);
    }
    return bits;
}

// Inverse of pack_board. Rejects (returns nullopt) any reserved bits set,
// any 3-bit field outside the valid piece codes, or any resulting board
// that fails is_valid_chess960 -- garbage in never produces a silently
// "valid-looking" board out.
inline std::optional<Position> unpack_board(uint64_t bits) {
    if (bits & ~uint64_t{0xFFFFFF}) return std::nullopt;

    Position pos{};
    for (int sq = 0; sq < 8; ++sq) {
        uint64_t code = (bits >> (3 * sq)) & 0x7ULL;
        if (code < 1 || code > 5) return std::nullopt;
        pos[sq] = static_cast<Piece>(code);
    }
    if (!is_valid_chess960(pos)) return std::nullopt;
    return pos;
}

inline std::string to_backrank_string(const Position& pos) {
    std::string s(8, '?');
    for (int sq = 0; sq < 8; ++sq) s[sq] = piece_to_char(pos[sq]);
    return s;
}

// Standard starting-position FEN. Castling rights are given as KQkq (all
// four available) rather than Shredder-FEN's file letters, since this is
// always the initial arrangement.
inline std::string to_fen(const Position& pos) {
    std::string white = to_backrank_string(pos);
    std::string black = white;
    for (char& c : black) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return black + "/pppppppp/8/8/8/8/PPPPPPPP/" + white + " w KQkq - 0 1";
}

} // namespace chess960
