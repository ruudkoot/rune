-- rows: lib.time.getclocktime lib.r.time.tocalendartime lib.time.tocalendartime lib.r.time.isdst
-- Report 24: getClockTime does not go back; toCalendarTime of it is in the local zone. It waits for B's primitive for the clock and the time zone.
module Main (main) where

import Time

main :: IO ()
main = do
  t1 <- getClockTime
  t2 <- getClockTime
  c <- toCalendarTime t1
  print (t2 >= t1, ctYear c >= 2000)
