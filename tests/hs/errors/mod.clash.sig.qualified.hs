-- Report 5.5.2: the name in a type signature is always unqualified: not F.sin :: Float -> Float.
module Main (main) where

import qualified Prelude as F
import Prelude hiding (sin)

F.sin :: Float -> Float
sin x = x

main :: IO ()
main = return ()
