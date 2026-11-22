module E (useE) where

import C (mkT)
import I ()

useE :: String
useE = show mkT
