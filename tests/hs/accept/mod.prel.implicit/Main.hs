-- rows: mod.prel.implicit.qualified mod.prel.explicit.qualified.ok mod.prel.explicit.several mod.prel.ordinary
-- Report 5.6.1: the Prelude is imported as by import Prelude, qualified names too; an explicit import replaces it, and
-- several add up.
module Main (main) where

import Uses
import Several

main :: IO ()
main = print (u, s)
