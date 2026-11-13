-- rows: R9 deviation
-- Report 3 says let x = True in x == x == True parses as (let x = True in (x == x)) == True, since == is
-- non-associative, and concedes that an implementation with a post-parsing pass for fixities may well deliver the
-- other parse. rhc parses by the meta-rule, the let extending as far to the right as it can, with operators flat, and
-- fixity resolution then refuses x == x == True (R9, as R1 for do: D38, on the ground that the stated parse cannot be
-- implemented, fixities being known only after names are resolved).
module Main (main) where

main :: IO ()
main = print (let x = True in x == x == True)
