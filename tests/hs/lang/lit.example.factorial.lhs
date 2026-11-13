-- rows: R52
-- Report 9.4's factorial example as printed, but for its `readLine`, which no module of the Report defines (R52, the
-- owner's call of 2026-11-10: a mistake in the Report): `getLine`, its likely meaning, reads the number.

   This literate program prompts the user for a number
   and prints the factorial of that number:

> main :: IO ()

> main = do putStr "Enter a number: "
>           l <- getLine
>           putStr "n!= "
>           print (fact (read l))

  This is the factorial function.

> fact :: Integer -> Integer
> fact 0 = 1
> fact n = n * fact (n-1)
