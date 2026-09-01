# Contributing to RookShift

RookShift contains a dependency-free C++17 implementation and matching Verilog RTL. Keep the software and hardware encodings aligned.

## Build and test

Build the C++ targets with:

```sh
make
./build/chess960_tests.exe
./build/chess960_message_tests.exe
```

The position suite must continue to round-trip all 960 Chess960 back ranks. For RTL changes, regenerate `data/chess960_positions.mem` and run the ModelSim flow documented in `README.md`; the expected result is 66 passing tests with the documented latencies.

## Change guidelines

- Use C++17 and retain the no-external-dependency core.
- Add malformed-input and boundary coverage for message-format changes.
- Update both C++ and Verilog implementations when an encoding or latency contract changes.
- Keep generated binaries, ModelSim work directories, and build output out of commits.

## Pull requests

Describe whether the change affects C++, RTL, or both. Include the two C++ test results and, for RTL work, the ModelSim summary and any intentional timing change.
