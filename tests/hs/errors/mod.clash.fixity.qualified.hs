-- Report 5.5.2: the name in a fixity declaration is always unqualified: not infixl 6 F.+.
module Main (main) where

import qualified Prelude as F
import Prelude

infixl 6 F.+

main :: IO ()
main = return ()
