-- rows: lib.r.ix.example.index lib.r.ix.example.inrange lib.r.ix.derive.numbering lib.r.ix.derive.range lib.r.ix.derive.index lib.r.ix.derive.inrange lib.r.ix.derive.enum lib.r.ix.derive.single
-- Report 15.1: derived Ix for an enumeration, numbered 0 to n-1 as by Enum, on the Report's Colour example; and for a
-- single-constructor type, as Figure 15.1 shows for tuples.
module Main (main) where

import Ix

data Colour = Red | Orange | Yellow | Green | Blue | Indigo | Violet deriving (Eq, Ord, Show, Enum, Ix)

data P = P Int Char deriving (Eq, Ord, Show, Ix)

main :: IO ()
main = do
  print (range (Yellow, Blue) == [Yellow, Green, Blue], index (Yellow, Blue) Green == 1, inRange (Yellow, Blue) Red == False)
  print (map (index (Red, Violet)) [Red .. Violet] == map fromEnum [Red .. Violet], rangeSize (Orange, Indigo), range (Blue, Yellow))
  print (range (P 1 'a', P 2 'b'))
  print ([index (P 1 'a', P 2 'b') p | p <- range (P 1 'a', P 2 'b')] == [index ((1, 'a'), (2, 'b')) (i, c) | (i, c) <- range ((1, 'a'), (2, 'b') :: (Int, Char))])
  print (inRange (P 1 'a', P 2 'b') (P 2 'c'), inRange (P 1 'a', P 2 'b') (P 1 'b'), rangeSize (P 1 'a', P 2 'b'))
