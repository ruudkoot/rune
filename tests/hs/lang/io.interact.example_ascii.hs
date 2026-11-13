-- rows: R47 R85 pre.r.interact.scope
-- Report 7.1, readings.md R85: the Report's example main = interact (filter isAscii), with the import Char it needs, on
-- ASCII input.
module Main (main) where

import Char

main :: IO ()
main = interact (filter isAscii)
