-- rows: mod.clash.tup.b mod.clash.tup.c mod.clash.tup.x.fixed
-- Report 5.5.2: names that do not resolve are no error until mentioned: the Report's tup, with B.x and C.x written.
module Main (main) where

import B
import C
import D

main :: IO ()
main = print tup

tup :: (Int, Int, Int, Int, Int)
tup = (b, c, d, B.x, C.x)
