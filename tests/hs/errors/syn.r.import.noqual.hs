-- Report 9.5: import -> var | tycon ... | tycls ...: an item of an import list is unqualified.
module Main (main) where

import Prelude (Prelude.id)

main :: IO ()
main = return ()
