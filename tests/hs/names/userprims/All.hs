-- A program whose modules are named as rhc's two modules of primitives: the
-- program's own, which it imports, not the library's (D36, the lead's
-- condition on hiding them).
module All () where

import PreludeBuiltin (primAnswer, primError)
import qualified UnicodePrims
import qualified Char

answer :: String
answer = primError (show (primAnswer + UnicodePrims.primUnicodeMaxChar))

upper :: Char
upper = Char.toUpper 'a'
