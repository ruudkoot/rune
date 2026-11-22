-- rows: R53
Report 9.4 (R53; ruling 49 makes the row a refusal): the Report does not say what a \begin{code} that no \end{code}
closes means. rhc's choice, R53's seed: an error, so this file, whose program text is never closed, is refused.

\begin{code}
module Main (main) where

main :: IO ()
main = print 1
