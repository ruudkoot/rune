structure LegacyProbe =
struct
  val _=List.app(fn round=>List.app(fn(name,args,rows,points)=>
    T.check("scs/replay-"^Int.toString round^"-"^name,fn()=>
      let val expected=Int.toString rows^":"^Int.toString points^":checked"
          fun run mode=(BenchScsCheck.run mode args=expected)handle ex=>
            (print("DETAIL "^name^" strict="^Bool.toString mode^" "^General.exnName ex^": "^General.exnMessage ex^"\n");false)
      in run false andalso run true end))ScsCases.values)(List.tabulate(8,fn i=>i))
end
