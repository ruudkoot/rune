-- rows: io.getline.eof pre.io.getline R46
-- Report 7.1, 21.9.2 (overlay ov.preludeio.getline, R46; M17's bottom probes on the literal Prelude): getLine as
-- hGetLine stdin, on "a", a newline and "bc" with none; the reference is the printed getLine (a loop of getChar)
-- under another name. They agree on the first line; at the end of the file the printed loop raises and loses "bc",
-- which hGetLine returns (R46's difference). A marker, then the lines; the last read is an IOError, end of file.
module Main (main) where

main :: IO ()
main = do
  putStrLn "probe"
  getLine >>= print
  getLine >>= print
  getLine >>= print
