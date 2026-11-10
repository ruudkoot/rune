-- rows: lib.r.time.tzname lib.r.time.roundtrip lib.r.time.toclocktime lib.r.time.addtoclocktime lib.r.time.diffclocktimes lib.r.time.timediff lib.r.time.range.day lib.r.time.range.hour lib.r.time.range.min lib.r.time.range.sec lib.r.time.range.picosec lib.r.time.range.yday lib.r.time.range.tz lib.time.toutctime lib.time.toclocktime lib.time.addtoclocktime lib.time.diffclocktimes lib.time.data.clocktime lib.time.inst.eqclocktime lib.time.inst.ordclocktime lib.r.time.clocktime
-- Report 24: toClockTime of a fixed CalendarTime and back by toUTCTime; adding a TimeDiff and taking the difference; the
-- fields' ranges, 31 December's day of the year; ClockTime's Eq and Ord. It waits for B's primitive for the clock and the time zone.
module Main (main) where

import Time

ct :: CalendarTime
ct = CalendarTime { ctYear = 2000, ctMonth = February, ctDay = 29, ctHour = 13, ctMin = 5, ctSec = 9, ctPicosec = 0, ctWDay = Tuesday, ctYDay = 59, ctTZName = "UTC", ctTZ = 0, ctIsDST = False }

dec31 :: Int -> CalendarTime
dec31 y = ct { ctYear = y, ctMonth = December, ctDay = 31 }

main :: IO ()
main = do
  let c = toClockTime ct
      u = toUTCTime c
  print (ctYear u, ctMonth u, ctDay u, ctHour u, ctMin u)
  print (ctSec u, ctPicosec u, ctWDay u, ctYDay u, ctTZName u)
  print (ctTZ u, ctIsDST u, toClockTime u == c)
  let d = TimeDiff 0 0 0 1 2 0 0
      c2 = addToClockTime d c
  print (c2 > c, c < c2, toClockTime (toUTCTime c2) == c2, addToClockTime (diffClockTimes c2 c) c == c2)
  print (ctHour (toUTCTime c2), ctMin (toUTCTime c2), ctYDay (toUTCTime (toClockTime (dec31 1999))), ctYDay (toUTCTime (toClockTime (dec31 2000))))
