-- Report 5.2: in the Report's Mod1 what came from Mod3 is not exported.
module Main (main) where

import Mod1

main :: IO ()
main = print m3
