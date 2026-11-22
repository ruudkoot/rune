-- rows: R64
-- Report 9.4: code "begins on the first line following a line that begins \begin{code}": the rest of that line
-- is not program, nor is the rest of the line that begins \end{code}.
\begin{code} the rest of this line is not program
module Main (main) where

main :: IO ()
main = return ()
\end{code} nor is the rest of this one
