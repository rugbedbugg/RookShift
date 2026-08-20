// Tests for chess960_message.hpp. There's no external oracle for "correct"
// message packing the way python-chess is one for the Chess960 numbering,
// so correctness here rests on round-tripping a wide sample of messages
// (including every padding-boundary length) plus explicit tests that
// malformed seed sequences are rejected rather than silently misdecoded.
#include "../src/chess960_message.hpp"

#include <cstdint>
#include <iostream>
#include <random>
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

void check_round_trip(const std::string& message, const std::string& label) {
    std::vector<int> seeds = chess960::encode_message(message);

    check(!seeds.empty(), label + ": encode produced no seeds");
    check(seeds.size() % chess960::kChunkDigits == 0,
          label + ": seed count is not a multiple of kChunkDigits");
    for (int s : seeds) {
        check(s >= 0 && s < 960, label + ": seed out of [0,959] range");
    }

    auto decoded = chess960::decode_message(seeds);
    check(decoded.has_value() && *decoded == message,
          label + ": round trip did not recover the original message");
}

} // namespace

int main() {
    using namespace chess960;

    // Boundary lengths around the 6-byte chunk size, both sides of every
    // multiple of kChunkBytes, since that's where padding-length arithmetic
    // is most likely to be off by one.
    for (int len = 0; len <= 20; ++len) {
        std::string message(static_cast<size_t>(len), 'x');
        for (int i = 0; i < len; ++i) message[static_cast<size_t>(i)] = static_cast<char>('a' + (i % 26));
        check_round_trip(message, "boundary length " + std::to_string(len));
    }

    check_round_trip("Hello world", "the running example");
    check_round_trip("", "empty message");
    check_round_trip(std::string("a\0b\0\0c", 6), "embedded null bytes");
    check_round_trip(std::string(1, '\xFF') + std::string(1, '\x00') + std::string(1, '\x80'),
                      "raw non-ASCII bytes");
    check_round_trip("The quick brown fox jumps over the lazy dog. 1234567890!@#$%^&*()",
                      "a longer sentence with punctuation and digits");

    // A wider randomized sample, including lengths well past a single chunk.
    std::mt19937 rng(12345);
    std::uniform_int_distribution<int> len_dist(0, 200);
    std::uniform_int_distribution<int> byte_dist(0, 255);
    for (int trial = 0; trial < 200; ++trial) {
        int len = len_dist(rng);
        std::string message(static_cast<size_t>(len), '\0');
        for (int i = 0; i < len; ++i) {
            message[static_cast<size_t>(i)] = static_cast<char>(byte_dist(rng));
        }
        check_round_trip(message, "random trial " + std::to_string(trial));
    }

    // Malformed input must be rejected, not silently misdecoded.
    check(!decode_message({}).has_value(), "empty seed list should be rejected");
    check(!decode_message({1, 2, 3, 4}).has_value(),
          "seed count not a multiple of kChunkDigits should be rejected");
    check(!decode_message({1, 2, 3, 4, 960}).has_value(),
          "an out-of-range seed (960) should be rejected");
    check(!decode_message({1, 2, 3, 4, -1}).has_value(),
          "a negative seed should be rejected");
    check(!decode_message({959, 959, 959, 959, 959}).has_value(),
          "an all-959 chunk (value >= 2^48, no legitimate encoder could produce it) should be rejected");
    {
        // Corrupting the single chunk that carries encode("")'s padding
        // (all 6 bytes = 0x06) by nudging its least-significant base-960
        // digit changes the reconstructed value by exactly +1 (or wraps),
        // which turns the trailing padding byte into something other than
        // six matching 0x06 bytes -- must be rejected, not silently accepted
        // as a different (wrong) message.
        std::vector<int> seeds = encode_message("");
        seeds.back() = (seeds.back() + 1) % 960;
        auto decoded = decode_message(seeds);
        check(!decoded.has_value(),
              "corrupting the padding-bearing chunk must be rejected");
    }

    std::cout << g_checks << " checks run, " << g_failures << " failures.\n";
    if (g_failures == 0) {
        std::cout << "All message encoding checks passed.\n";
    }
    return g_failures == 0 ? 0 : 1;
}
