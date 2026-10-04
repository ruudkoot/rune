# fft with its arrays of reals as RealArray, the flat array of
# docs/plans/heap-layout.md's M8, where the program has Array at the type
# real: its two arrays are made by `array (np+2, 0.0)` and read and written
# by the `sub` and `update` that this line opens.
s/^open Array Math$/open RealArray Math/
