-- H5 (E13, GHC's case): U's instance's context, which D's derived instance takes on.
module U where

data U a = U a

instance Show a => Show (U a) where
  show (U a) = "U " ++ show a
