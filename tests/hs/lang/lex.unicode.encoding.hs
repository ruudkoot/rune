-- rows: lex.unicode.newversions R5
-- Report 2.1 (R5; ruling 49 makes these two rows of test none a run): the Report never says how source text is
-- encoded as bytes, and expects new versions of Unicode to be used as they appear. rhc reads its source as UTF-8, so
-- "é€" is the characters 233 and 8364; and it follows Unicode 18.0.0, lib/unicode's version: the Garay letters, new
-- in Unicode 16.0 and unassigned in the Report's 3.0 ([11]), are a small letter that begins an identifier, and to
-- Char a capital and a small letter.
module Main (main) where

import Char

𐵰 :: Int
𐵰 = 2

main :: IO ()
main = do
  print (map fromEnum "é€")
  print (𐵰 + 1, isUpper (chr 0x10D50), isLower (chr 0x10D70))
