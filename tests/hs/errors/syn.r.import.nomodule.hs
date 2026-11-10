-- Report 9.5: import -> var | tycon ... | tycls ...: `module M` is no item of an import list.
module Main (main) where

import Prelude (module Prelude)

main :: IO ()
main = return ()
