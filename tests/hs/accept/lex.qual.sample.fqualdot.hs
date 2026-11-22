-- Report 2.4, the table of samples: `F..` lexes as `F..`, the operator `.` qualified by `F`.
module Main (main) where

import qualified Prelude as F
import Prelude

main :: IO ()
main = print ((negate F.. succ) 1 :: Int)
