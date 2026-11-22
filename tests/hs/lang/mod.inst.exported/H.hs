module H (useH) where

import C hiding (T)
import I

useH :: String
useH = show mkT
