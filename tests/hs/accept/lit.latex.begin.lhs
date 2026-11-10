-- rows: lit.latex.end lit.latex.comment lit.latex.noblank lit.latex.sameext
-- Report 9.4: "program code begins on the first line following a line that begins \begin{code}, and ends just
-- before a subsequent line that begins \end{code}"; everything else is comment, and no blank lines are needed.
\documentstyle{article}
\begin{document}
Text of the paper.
\begin{code}
module Main (main) where

main :: IO ()
main = print (product [1 .. 20 :: Integer])
\end{code}
More text.
\end{document}
