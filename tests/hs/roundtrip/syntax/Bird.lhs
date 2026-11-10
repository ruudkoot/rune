A literate script, in the style of bird tracks (9.4).

> module Bird where

Commentary between program lines needs a blank line on each side.

> main :: IO ()
> main = putStrLn "a string \
>                 \with a gap across two lines"
>   where x = 1

> -- a comment on a program line
> f x = x
