-- Report 5.3.3: the shared qualifier's Q.f names two entities.
module Main (main) where

import qualified Foo as Q
import qualified Baz2 as Q

main :: IO ()
main = print Q.f
