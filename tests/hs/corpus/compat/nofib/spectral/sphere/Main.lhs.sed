# nofib's spectral/sphere hashes its picture with a hash of its own, over Int and wrapping at 64 bits. For rhc's
# corpus it is over Integer, reduced to the same 64-bit two's-complement value at each step (D22), as NofibUtils's.
s/^> hash :: \[Vector\] -> Int$/> hash :: [Vector] -> Integer/
s/^> hash = foldr (\\(r,g,b) acc -> u8 r + u8 g\*7 + u8 b\*23 + acc\*61) 0$/> hash = foldr (\\(r,g,b) acc -> wrap64 (u8 r + u8 g*7 + u8 b*23 + acc*61)) 0/
/^>     u8 = round \. (255\*)$/a\
>     wrap64 n = let m = n `mod` 18446744073709551616\
>                in if m >= 9223372036854775808 then m - 18446744073709551616 else m
