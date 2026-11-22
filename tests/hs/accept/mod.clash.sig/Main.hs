-- rows: mod.clash.fixity mod.clash.fixity.method
-- Report 5.5.2: a signature's and a fixity declaration's names are those of their declaration list: the Report's
-- F with its own sin beside the Prelude's; a local + with its fixity; a method's fixity at the top.
module Main (main) where

import qualified Prelude as P
import Prelude

sin :: Float -> Float
sin x = x

infixl 6 +
(+) :: Int -> Int -> Int
a + b = a P.- b

class C a where
  (+++) :: a -> a -> a
infixl 6 +++

main :: IO ()
main = print (Main.sin 1, P.sin 0, 3 Main.+ 1)
