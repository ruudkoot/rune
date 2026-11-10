-- Report 2.2: ascSymbol -> ! | # | $ | % | & | * | + | . | / | < | = | > | ? | @ | \ | ^ | | | - | ~: each begins an
-- operator, alone where it is not reserved and with another symbol where it is (2.4: = @ \ | ~ and their kin).
module Main (main) where

main :: IO ()
main = print [1 ! 2, 1 # 2, 1 $$ 2, 1 % 2, 1 & 2, 1 *! 2, 1 +! 2, 1 .! 2, 1 /! 2, 1 <! 2, 1 =! 2, 1 >! 2, 1 ? 2, 1 @! 2, 1 \! 2, 1 ^! 2, 1 |! 2, 1 -! 2, 1 ~! 2]
  where
    a ! b = a + b :: Int
    a # b = a + b
    a $$ b = a + b
    a % b = a + b
    a & b = a + b
    a *! b = a + b
    a +! b = a + b
    a .! b = a + b
    a /! b = a + b
    a <! b = a + b
    a =! b = a + b
    a >! b = a + b
    a ? b = a + b
    a @! b = a + b
    a \! b = a + b
    a ^! b = a + b
    a |! b = a + b
    a -! b = a + b
    a ~! b = a + b
