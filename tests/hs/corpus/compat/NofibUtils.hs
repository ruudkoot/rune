-- nofib's common/NofibUtils.hs for rhc's corpus, in Haskell 98 (D22). nofib's hash folds a string into an Int that
-- wraps at 64 bits. This one folds it into an Integer reduced to the same 64-bit two's-complement value at each
-- step, so a program prints what GHC's 64-bit Int prints, on every oracle and on rhc, whose Int overflow is an error.
module NofibUtils (hash, salt) where

import Char (ord)

hash :: String -> Integer
hash = go 0
  where go acc [] = acc
        go acc (c:cs) = let acc' = wrap64 (toInteger (ord c) + acc * 31) in acc' `seq` go acc' cs

-- n as a 64-bit two's-complement number
wrap64 :: Integer -> Integer
wrap64 n = let m = n `mod` 18446744073709551616
           in if m >= 9223372036854775808 then m - 18446744073709551616 else m

salt :: a -> IO a
salt = return
