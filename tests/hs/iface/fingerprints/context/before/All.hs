-- An instance's context is its own (H5): it moves alone, the type it is of stays.
module All (Box(..)) where

data Box a = Box a

instance Show a => Show (Box a) where
  show (Box x) = show x
