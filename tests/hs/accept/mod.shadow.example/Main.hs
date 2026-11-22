-- rows: mod.shadow.def mod.shadow.importer.ok mod.shadow.myprelude
-- Report 5.6.2: the Report's A redefines null, hiding the Prelude's; a definition of a Prelude name with no use of it is
-- legal; an importer may hide as A does; and a module may serve in place of the Prelude.
module Main (main) where

import A2
import Prelude hiding (null)
import B2
import qualified Def

main :: IO ()
main = print (null 0, nonNull 1, b, Def.null)
