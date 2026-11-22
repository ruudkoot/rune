-- Report 5.6.2: the Prelude's instances cannot be hidden: instance Show Char again.
module Main (main) where

import Prelude hiding (Show)
import qualified Prelude as P

instance P.Show Char where
  show _ = "c"

main :: IO ()
main = P.return ()
