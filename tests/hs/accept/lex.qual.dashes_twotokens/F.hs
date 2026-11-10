-- The module of lex.qual.dashes_twotokens: an operator `-` of its own, looser than negation.
module F ((-)) where

import Prelude hiding ((-))
import qualified Prelude

infixl 5 -

(-) :: Int -> Int -> Int
a - b = a Prelude.- b
