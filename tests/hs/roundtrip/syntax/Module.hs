-- The module header, exports and imports of the Report's section 5 and
-- the grammar of 9.5: every form of export and import.
module Module
  ( f, g
  , (+++), Module.h          -- a qualified variable
  , T(..), U(A, B), V()      -- a type with all, some, none of its constructors
  , R(field1, field2)        -- a record's fields
  , C(..), D(method), E
  , module List
  , module Module
  , ) where                  -- a trailing comma

import Prelude
import qualified List as L
import Char (isUpper, isLower, toUpper)
import Maybe hiding (fromJust, (?), Maybe(..), Either(Left))
import qualified Map
import Ratio ((%), Ratio)
import Monad ()
import IO (,)
import List as Lst hiding ()

infixr 5 +++

f, g :: Int -> Int
f x = x
g = \x -> x + 1

(+++) :: [a] -> [a] -> [a]
xs +++ ys = xs ++ ys

h :: Int
h = 0

data T = T1 | T2
data U = A | B | B2
data V = V1
data R = R { field1 :: Int, field2, field3 :: Bool }

class C a
class D a where method :: a -> a
class E a
