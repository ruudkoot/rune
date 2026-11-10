-- With --dotted-names, A.B is one module name, and A.B.y one qualified name.
module All () where

import qualified A.B

z :: Int
z = A.B.y + 1
