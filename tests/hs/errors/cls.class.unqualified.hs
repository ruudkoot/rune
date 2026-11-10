-- rows: R71
-- Report 4.3.1: the class declared is an unqualified tycls: not class M.C a.
module Main (main) where

import qualified Prelude as M
import Prelude

class M.C a where

main :: IO ()
main = return ()
