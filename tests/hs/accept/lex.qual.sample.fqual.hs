-- Report 2.4, the table of samples: `F.g` lexes as one token, `g` qualified by `F`.
module Main (main) where

import qualified Prelude as F
import Prelude

main :: IO ()
main = print (F.negate 1 :: Int)
