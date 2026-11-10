-- The Report's 20 modules (the haskell98 roadmap's M13, D36): the 11-module unit of the
-- Prelude checks as one unit, floatToDigits with no annotation where its type
-- depends on defaulting (E16), and the 9 above it; the only errors are the 8
-- names of 10 uses that do not resolve as printed, until M17's overlay.
module All () where

import qualified Array
import qualified CPUTime
import qualified Char
import qualified Complex
import qualified Directory
import qualified IO
import qualified Ix
import qualified List
import qualified Locale
import qualified Maybe
import qualified Monad
import qualified Numeric
import qualified Random
import qualified Ratio
import qualified System
import qualified Time
