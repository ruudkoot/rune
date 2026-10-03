"""Independent dictionary LZW, packing and mathematical 64-bit hash oracle.

Run from the repository root after importing the committed compressor fixtures.
The runnable SML encoder uses persistent prefix trees, not this dictionary.
"""
from pathlib import Path


def encode(data):
    dictionary = {bytes([value]): value for value in range(256)}
    next_code = 256
    result = []
    word = b''
    for value in data:
        byte = bytes([value])
        if word + byte in dictionary:
            word += byte
        else:
            result.append(dictionary[word])
            if next_code < 4096:
                dictionary[word + byte] = next_code
            next_code += 1
            word = byte
    if word:
        result.append(dictionary[word])
    return result


def pack(codes):
    result = []
    for index in range(0, len(codes) - 1, 2):
        first, second = codes[index:index + 2]
        result.extend([first // 16, (first % 16) * 16 + second // 256, second % 256])
    if len(codes) % 2:
        result.extend([codes[-1] // 16, codes[-1] % 16])
    return bytes(result)


def signed_hash(data):
    value = 0
    for byte in data:
        value = (value * 31 + byte) % (2**64)
    return value if value < 2**63 else value - 2**64


suite = Path('examples/benchmarks/compress-lazy')
for profile, repetitions in [('smoke', 1), ('normal', 200), ('large', 200)]:
    data = (suite / 'DATA' / profile / 'input.bin').read_bytes()
    fixtures = []
    for cut in range(31):
        expected = (suite / 'expected' / profile / f'cut-{cut:02d}.bin').read_bytes()
        actual = pack(encode(data[:max(0, len(data) - cut)]))
        assert actual == expected, (profile, cut)
        fixtures.append(expected)
    hashes = [signed_hash(fixtures[index % 31]) for index in range(1, repetitions + 1)]
    expected_sum = int((suite / f'{profile}.expected').read_text().replace('~', '-'))
    assert sum(hashes) == expected_sum
    reference = 'fast-hashes.txt' if profile == 'normal' else 'norm-hashes.txt'
    if profile != 'smoke':
        recorded = Path('examples/benchmarks/results/m4-compress/reference-observers') / reference
        assert hashes == list(map(int, recorded.read_text().split()))
    print(profile, 'all 31 byte fixtures and selected hash samples agree')

seed = 47
noise = []
for _ in range(8192):
    seed = (seed * 1664525 + 1013904223) % (2**32)
    noise.append(seed >> 24)
codes = encode(bytes(noise))
assert len(codes) > 4096 and max(codes) < 4096
assert pack(codes) == Path('tests/benchmarks/data/compress-freeze.bin').read_bytes()
print('dictionary freeze fixture agrees')
