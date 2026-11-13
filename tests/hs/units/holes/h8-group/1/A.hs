-- M22: a recursive type group across a cycle's members, T in A and U in B, hashed as one; Main reads U alone.
module A where

import B

data T = L | N U
