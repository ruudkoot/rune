-- HsLint's second inference on the Report's library (the roadmap's D36, E16): every module a program
-- may import, and through them the Prelude's 11-module cycle, inferred as one unit, each signature of
-- the library checked; with --dump-hslint=library, the 7 unsigned values E16 counts and the
-- defaults the library's own code chooses (the one in floatToDigits among them).
module Main (main) where

import Array
import CPUTime
import Char
import Complex
import Directory
import IO
import Ix
import List
import Locale
import Maybe
import Monad
import Numeric
import Random
import Ratio
import System
import Time

main :: IO ()
main = return ()
