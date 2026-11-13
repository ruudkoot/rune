-- A type of another module that a value mentions moves the value with it; a value that does not mention it stays.
module All (useT, other) where

import A (T)

useT :: T -> Int
useT _ = 0

other :: Int
other = 1
