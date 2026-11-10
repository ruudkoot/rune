-- Report 2.4: reservedid -> case | class | data | default | deriving | do | else | if | import | in | infix |
-- infixl | infixr | instance | let | module | newtype | of | then | type | where | _: `do` is no variable.
module Main (main) where

main :: IO ()
main = print (do :: Int)
  where do = 1
