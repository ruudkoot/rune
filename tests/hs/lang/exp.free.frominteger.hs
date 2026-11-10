-- rows: exp.free.fromrational
-- Report 3: free variables and constructors of the translations always refer to the Prelude's entities, whatever is
-- in scope: a literal is converted by the class methods fromInteger and fromRational, not the module's, which abort.
module Main (main) where

import Prelude hiding (fromInteger, fromRational)

fromInteger :: Integer -> Int
fromInteger _ = error "own"

fromRational :: Rational -> Double
fromRational _ = error "own"

main :: IO ()
main = print (3 :: Int, 2.5 :: Double, 7 :: Integer)
