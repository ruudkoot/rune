-- rows: lex.hexit lex.int.decimal lex.int.incomplete.oct
-- Report 2.5: decimal -> digit{digit}; octal -> octit{octit}; hexadecimal -> hexit{hexit}; integer -> decimal | 0o octal
-- | 0O octal | 0x hexadecimal | 0X hexadecimal. octit -> 0 to 7, so `0o8` and `0o9` lex as `0` then a varid:
-- here two patterns of f.
module Main (main) where

f :: Int -> Int -> Int
f 0o8 = o8
f 0o9 = o9
f _ _ = 0

main :: IO ()
main = print ([0, 007, 123, 0o7, 0O17, 0x1F, 0Xab, 0xAb] :: [Int], f 0 1)
