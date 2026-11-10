\documentclass{article}
\begin{document}
A literate script in the style of \LaTeX, between begin and end of code.
\begin{code}
module Latex where

main :: IO ()
main = print 1
\end{code}
More commentary, which may touch the code.
\begin{code}
f = 2
  where
    g = 3
\end{code}
\end{document}
