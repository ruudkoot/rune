-- Correctness-only adapter: retain ST state semantics with boxed storage.
-- This is not used for performance comparisons with the original runtime.
module Data.STRef.Unboxed (STRefU,newSTRefU,readSTRefU,writeSTRefU) where
import Data.STRef
import Control.Monad.ST
type STRefU s a = STRef s a
newSTRefU :: a -> ST s (STRefU s a)
newSTRefU value = value `seq` newSTRef value
readSTRefU :: STRefU s a -> ST s a
readSTRefU = readSTRef
writeSTRefU :: STRefU s a -> a -> ST s ()
writeSTRefU ref value = value `seq` writeSTRef ref value
