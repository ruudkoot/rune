-- A default by N where Read N is in scope, Integer where it is not (4.3.4,
-- 5.4): what A's unit makes rests on Mid's imports, which are not A's.
module A where

import N
import Mid

default (N, Integer)

a :: String
a = show (read "5" + 1)
