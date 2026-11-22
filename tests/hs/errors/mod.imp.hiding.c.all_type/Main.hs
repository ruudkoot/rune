-- rows: R75
-- Report 5.3.1: hiding (C) excludes any type, class or constructor named C: the constructor.
module Main (main) where

import M hiding (C)

main :: IO ()
main = case C of _ -> return ()
