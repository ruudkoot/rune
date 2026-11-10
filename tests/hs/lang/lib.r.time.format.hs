-- rows: lib.time.show2 lib.time.show2p lib.time.show3 lib.time.formatcalendartime lib.time.calendartimetostring lib.r.time.calendartimetostring lib.r.time.enums lib.time.data.month lib.time.data.day lib.time.data.calendartime lib.time.data.timediff lib.r.locale.default lib.r.locale.used lib.locale.data.timelocale lib.locale.defaulttimelocale R49
-- Report 24, 25: formatCalendarTime with defaultTimeLocale and with a user TimeLocale on a fixed CalendarTime, each directive
-- the Report's code gives; calendarTimeToString is %c; the enumerations of Month and Day; defaultTimeLocale's fields.
module Main (main) where

import Time
import Locale

ct :: CalendarTime
ct = CalendarTime { ctYear = 2000, ctMonth = February, ctDay = 29, ctHour = 13, ctMin = 5, ctSec = 9, ctPicosec = 0, ctWDay = Tuesday, ctYDay = 59, ctTZName = "UTC", ctTZ = 0, ctIsDST = False }

td0 :: TimeDiff
td0 = TimeDiff 0 0 0 0 0 0 0

fr :: TimeLocale
fr = defaultTimeLocale { months = [(m, take 3 m) | m <- ["janvier", "fevrier", "mars", "avril", "mai", "juin", "juillet", "aout", "septembre", "octobre", "novembre", "decembre"]] }

main :: IO ()
main = do
  putStrLn (formatCalendarTime defaultTimeLocale "%Y-%m-%d %H:%M:%S %a %A %b %B %j %p %y" ct)
  putStrLn (formatCalendarTime fr "%B %b" ct)
  print (calendarTimeToString ct == formatCalendarTime defaultTimeLocale "%c" ct)
  print ([January ..] == map toEnum [0 .. 11], fromEnum December, [Sunday ..] == map toEnum [0 .. 6], succ Monday)
  print (take 2 (wDays defaultTimeLocale), take 2 (months defaultTimeLocale), amPm defaultTimeLocale)
  print (dateFmt defaultTimeLocale, timeFmt defaultTimeLocale, time12Fmt defaultTimeLocale)
  print (tdYear td0, tdHour (TimeDiff 0 0 0 1 2 0 0), TimeDiff 0 0 0 0 0 0 0 == td0)
