(* LexiFi SAS, copyright 2000-2013. GPL version 3 or later.
 * Direct SML97 translation of the pinned benchmark date.ml. *)
structure BenchG2Date=
struct
 type date=int
 type gregorian={year:int,month:int,day:int,hour:int,minute:int}
 val minutesInDay=1440
 fun ofGregorian{year=y,month=m,day=d,hour=hr,minute=mn}=
   ((if m=1 orelse m=2 then
      Int.quot(1461*(y+4800-1),4)+Int.quot(367*(m+10),12)-
        Int.quot(3*Int.quot(y+4900-1,100),4)
     else Int.quot(1461*(y+4800),4)+Int.quot(367*(m-2),12)-
        Int.quot(3*Int.quot(y+4900,100),4))
     +d-32075-2444238)*minutesInDay+hr*60+mn
 fun toGregorian minutes=
   let val jul=Int.quot(minutes,minutesInDay)
       val l=jul+68569+2444238
       val n=Int.quot(4*l,146097)
       val l=l-Int.quot(146097*n+3,4)
       val i=Int.quot(4000*(l+1),1461001)
       val l=l-Int.quot(1461*i,4)+31
       val j=Int.quot(80*l,2447)
       val d=l-Int.quot(2447*j,80)
       val l=Int.quot(j,11)
       val m=j+2-12*l
       val y=100*(n-49)+i+l
       val daytime=Int.rem(minutes,minutesInDay)
   in {year=y,month=m,day=d,hour=Int.quot(daytime,60),minute=Int.rem(daytime,60)}end
 fun checkDate year month day=
   day>=1 andalso month>=1 andalso month<=12 andalso year>=1980 andalso year<=2299 andalso
   (day<=28 orelse
    (case month of 2=>day=29 andalso year mod 4=0 andalso(year=2000 orelse year mod 100<>0)
      |4=>day<=30|6=>day<=30|9=>day<=30|11=>day<=30|_=>day<=31))
 fun ofString text=
   let val _=if String.size text<10 then raise Fail"invalid date"else()
       fun sub start count=
         let fun loop total i left=if left=0 then total
               else loop(total*10+Char.ord(String.sub(text,i))-48)(i+1)(left-1)
         in loop 0 start count end
       val year=sub 0 4 val month=sub 5 2 val day=sub 8 2
       val _=if checkDate year month day then()else raise Fail"invalid date"
       val(hour,minute)=if String.size text<16 then(12,0)else(sub 11 2,sub 14 2)
   in ofGregorian{year=year,month=month,day=day,hour=hour,minute=minute}end
 fun daysBetween t1 t2=Real.fromInt(t1-t2)/1440.0
 fun act365 t1 t2=daysBetween t1 t2/365.0
 fun leap year=year mod 4=0 andalso(year mod 100<>0 orelse year mod 400=0)
 fun endOfMonth year month=case month of 2=>if leap year then 29 else 28
   |4=>30|6=>30|9=>30|11=>30|_=>31
 fun addMonths date amount=
   let val{year,month,day,hour,minute}=toGregorian date
       val m=month+amount
       val y=year+Int.quot(m-1,12)
       val m=Int.rem(m-1,12)+1
       val(y,m)=if m<=0 then(y-1,m+12)else(y,m)
   in ofGregorian{year=y,month=m,day=Int.min(day,endOfMonth y m),hour=hour,minute=minute}end
 fun addYears date amount=addMonths date(amount*12)
 val maxDate=ofString"2299-12-31T23:59:59"
 val minDate=ofString"1980-01-01T12:00:00"
end
