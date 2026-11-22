-- rows: mod.structure.body.empty R34
-- Report 5.1: a module may have no declaration, or neither imports nor declarations (R34).
module Main (main) where

import Empty
import Bare

main :: IO ()
main = return ()
