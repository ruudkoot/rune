-- Report 4.5.5's example: (len1, len2) = genericLength xs with a signature is one traversal at one type; this runs now and waits
-- for a --count budget that shows the traversal shared (tests/hs/perf, rhc's policy).
module Main (main) where

import List

xs :: [Int]
xs = [1 .. 1000]

len1, len2 :: Integer
(len1, len2) = let l = genericLength xs in (l, l)

main :: IO ()
main = print (len1, len2)
