-- rows: mod.alias.shared.unused
-- Report 5.3.3: two modules may share a qualifier where every name still resolves, and two entities under one name
-- clash only where mentioned.
module Main (main) where

import qualified Foo as Q
import qualified Baz as Q
import qualified Baz2 as Q

main :: IO ()
main = print (Q.g, Q.h)
