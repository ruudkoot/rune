-- E16's fixture imp (results/E16/tests/imp): T1 re-exports the Prelude's
-- names through a qualified import, T2 and T3 import it, and the whole
-- library is read, as E16 read it: 690 pairs at the least fixpoint, 693 at
-- the greatest, where the Prelude's map circulates.
module All () where

import T2
import T3
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
