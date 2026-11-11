# sphere-lazy's upstream is nofib's spectral/sphere, byte for byte (examples/benchmarks/sphere-lazy/upstream/Main.lhs),
# so its harness variant takes the same edit, tests/hs/corpus/compat/nofib/spectral/sphere/Main.lhs.sed (the lead's
# ruling 54, D22's line in kind): its own hash over Integer, reduced to GHC's 64-bit wrapped value at each step.
s/^> hash :: \[Vector\] -> Int$/> hash :: [Vector] -> Integer/
s/^> hash = foldr (\\(r,g,b) acc -> u8 r + u8 g\*7 + u8 b\*23 + acc\*61) 0$/> hash = foldr (\\(r,g,b) acc -> wrap64 (u8 r + u8 g*7 + u8 b*23 + acc*61)) 0/
/^>     u8 = round \. (255\*)$/a\
>     wrap64 n = let m = n `mod` 18446744073709551616\
>                in if m >= 9223372036854775808 then m - 18446744073709551616 else m
