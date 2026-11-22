module A3 (null, nonNull) where

null, nonNull :: Int -> Bool
null x = x == 0
nonNull x = not (null x)
