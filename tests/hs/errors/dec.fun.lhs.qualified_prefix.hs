-- Report 4.4.3: funlhs -> var apat {apat}: the function's name is unqualified: not M.f x = 1.
module Main (main) where

import qualified Prelude as M
import Prelude

M.f x = 1

main :: IO ()
main = return ()
