-- rows: R38
-- Report 7.1 (R38; ruling 49 makes the row a run): the character functions "cannot be used portably for binary I/O",
-- 8-bit behaviour being a decision on Char and on the encoding. rhc's: a Char is any code point and the standard
-- handles carry UTF-8, so a character above 127 goes out as its UTF-8 bytes, 233 as two and 8364 as three, and 127
-- as itself.
module Main (main) where

main :: IO ()
main = putStrLn ['\233', '\8364', '\127']
