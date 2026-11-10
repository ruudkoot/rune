-- Report 4.4.3: funlhs -> pat varop pat: the operator is unqualified: not x `M.f` y = 1.
module Main (main) where

import qualified Prelude as M
import Prelude

x `M.f` y = 1

main :: IO ()
main = return ()
