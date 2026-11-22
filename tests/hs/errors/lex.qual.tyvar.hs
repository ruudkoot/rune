-- Report 2.4: qualified names are qvarid, qconid, qtycon, qtycls, qvarsym and qconsym, "Type variables ... are not
-- qualified": `M.a` is no type.
module Main (main) where

import qualified Prelude as M
import Prelude

f :: M.a -> M.a
f x = x

main :: IO ()
main = return ()
