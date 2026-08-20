// Multi-position message encoding: packs an arbitrary byte string into a
// sequence of Chess960 seeds, and back.
//
// Each seed carries log2(960) ~= 9.9 bits. Rather than the wasteful
// one-byte-per-seed mapping (which would only ever use seeds 0-255, a
// statistically obvious fingerprint against the paper's own uniform-entropy
// argument for undetectability), the message is packed in 6-byte chunks:
// each chunk's 48-bit value is converted to exactly 5 base-960 digits via
// plain 64-bit integer arithmetic (960^5 ~= 8.15e14, far under UINT64_MAX,
// so no arbitrary-precision arithmetic is needed). That's ~9.6 bits of
// payload per seed -- 97% of the theoretical maximum -- and spreads seed
// values uniformly across the full 0-959 range.
//
// The final chunk is PKCS7-padded (1-6 marker bytes, always present, even
// for an already-block-aligned message) so decode always knows exactly
// where the message ends without a separate length field.
#pragma once

#include <array>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace chess960 {

constexpr int kChunkBytes = 6;
constexpr int kChunkDigits = 5;
constexpr uint64_t kChunkDigitBase = 960;
constexpr uint64_t kChunkValueLimit = 1ULL << (8 * kChunkBytes); // 2^48

// Packs `message` (arbitrary bytes) into a sequence of Chess960 seeds.
inline std::vector<int> encode_message(const std::string& message) {
    std::string padded = message;
    int pad_len = kChunkBytes - static_cast<int>(padded.size() % kChunkBytes);
    // PKCS7: always add 1..kChunkBytes padding bytes, never zero, so a
    // block-aligned message still gets a full padding block to strip.
    padded.append(static_cast<size_t>(pad_len), static_cast<char>(pad_len));

    std::vector<int> seeds;
    seeds.reserve((padded.size() / kChunkBytes) * kChunkDigits);

    for (size_t offset = 0; offset < padded.size(); offset += kChunkBytes) {
        uint64_t value = 0;
        for (int i = 0; i < kChunkBytes; ++i) {
            value = (value << 8) | static_cast<uint8_t>(padded[offset + i]);
        }

        std::array<int, kChunkDigits> digits{};
        uint64_t remaining = value;
        for (int i = kChunkDigits - 1; i >= 0; --i) {
            digits[i] = static_cast<int>(remaining % kChunkDigitBase);
            remaining /= kChunkDigitBase;
        }
        for (int digit : digits) seeds.push_back(digit);
    }

    return seeds;
}

// Inverse of encode_message. Returns std::nullopt for anything that isn't a
// well-formed encoding: wrong seed count, an out-of-range seed, a chunk
// value beyond what any legitimate 6-byte chunk could produce, or corrupt
// padding -- garbage in never produces a silently "valid-looking" message.
inline std::optional<std::string> decode_message(const std::vector<int>& seeds) {
    if (seeds.empty() || seeds.size() % kChunkDigits != 0) return std::nullopt;

    std::string padded;
    padded.reserve((seeds.size() / kChunkDigits) * kChunkBytes);

    for (size_t offset = 0; offset < seeds.size(); offset += kChunkDigits) {
        uint64_t value = 0;
        for (int i = 0; i < kChunkDigits; ++i) {
            int digit = seeds[offset + i];
            if (digit < 0 || digit >= static_cast<int>(kChunkDigitBase)) return std::nullopt;
            value = value * kChunkDigitBase + static_cast<uint64_t>(digit);
        }
        // Not every 5-digit base-960 combination corresponds to a chunk a
        // real encoder could have produced (960^5 > 2^48); reject the rest.
        if (value >= kChunkValueLimit) return std::nullopt;

        for (int i = kChunkBytes - 1; i >= 0; --i) {
            padded.push_back(static_cast<char>((value >> (8 * i)) & 0xFF));
        }
    }

    int pad_len = static_cast<uint8_t>(padded.back());
    if (pad_len < 1 || pad_len > kChunkBytes || static_cast<size_t>(pad_len) > padded.size()) {
        return std::nullopt;
    }
    for (size_t i = padded.size() - pad_len; i < padded.size(); ++i) {
        if (static_cast<uint8_t>(padded[i]) != static_cast<uint8_t>(pad_len)) return std::nullopt;
    }

    return padded.substr(0, padded.size() - pad_len);
}

} // namespace chess960
