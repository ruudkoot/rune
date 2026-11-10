-- rows: lit.bird.comment lit.bird.replace lit.bird.layout lit.bird.blank lit.bird.comments lit.ext.lhs
-- Report 9.4: "a line in which ">" is the first character is treated as part of the program; all other lines are
-- comment"; the > is replaced by a space, and layout and comments apply to the text that results. A line of
-- blanks separates comment from program, and a nested comment may span program lines.

> module Main (main) where

Prose between the blocks is comment, kept off the program lines by blank lines.
 	
> main :: IO ()
> main = print (f 1)
>   where {- a nested comment
> spanning program lines -} f x = x
>                                      + 1 :: Int
