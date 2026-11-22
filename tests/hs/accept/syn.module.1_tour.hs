-- rows: syn.body.1 syn.impdecls.1 syn.exports.1 syn.export.1 syn.export.2 syn.export.3 syn.export.4 syn.impdecl.1 syn.impdecl.2 syn.impspec.1 syn.impspec.2 syn.import.1 syn.import.2 syn.import.3 syn.cname.1 syn.topdecls.1 syn.r.exports.trailing syn.r.impspec.trailing syn.r.impdecl.empty syn.r.nominalnames
-- Report 9.5: module -> module modid [exports] where body; body -> { impdecls ; topdecls }; exports, export, impdecl,
-- impspec and import in each of their forms, a trailing comma in an export and an import list, an empty
-- import (the ; ; below), and as, qualified and hiding used as variables.
module Main (main, T(..), U(A, b), C(..), D(d1, d2), module Char, f,) where

import Prelude
import qualified Prelude as P
import Char
import qualified List as L (sort, nub,)
import Maybe hiding (fromJust,)
import Ratio (Ratio, Rational, (%))
import Prelude (Maybe(..), Either(Left, Right), Eq((==)), Show(..),) ; ;
import Monad ()

data T = T Int
data U = A | B { b :: Int }
class C a where c :: a -> Int
class D a where { d1 :: a -> Int; d2 :: a -> Int }

f :: Int -> Int
f as = as + hiding + qualified where { hiding = 1; qualified = 2 }

main :: IO ()
main = print (L.sort [3, 1, 2 :: Int], ord 'a', 1 % 2 :: Rational, P.id (f 0), fromMaybe 0 Nothing)
