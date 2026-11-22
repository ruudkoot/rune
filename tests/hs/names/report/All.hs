-- The Report's 20 modules (the haskell98 roadmap's M12, D36): every module of
-- the library a program can import, and through the Prelude the three it
-- cannot, with the two of rhc's primitives; All exports nothing of its own,
-- so that the dump is the library's (E16's results/E16/resolve.txt).
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
