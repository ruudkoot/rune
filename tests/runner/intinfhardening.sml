(* Malformed primitive arguments, backend policy across fork, saved-policy
   fields and allocation failures. Fixtures reproduce invalid public inputs. *)
structure IntInfHardening =
struct
  open IntInfChecks
  fun one (c : context) forkOnly native allocationTest () =
    let val gmp=hasGMP c
        fun compile name target=IntInfChecks.compile c name (source c "hardening" name) target ["--allow-prim"]
        fun invoke label overrides args=execute c label 60 overrides args
        val fork=compile "fork" "registers"
        val modes=if gmp then ["sml","gmp"] else ["sml"]
        fun forkMode mode emulated inherited=
          let val overrides=case inherited of NONE => [] | SOME value => [("RUNEVM_INTINF",value)]
              val result=invoke "fork" overrides ([#vm c,"--intinf=" ^ mode] @ (if emulated then ["--emulate-fork"] else []) @ [fork])
          in output result "child policy preserved\nparent pass\n" end
        val ()=List.app (fn mode => List.app (fn emulated => List.app (forkMode mode emulated)
                    [NONE,SOME (if mode="sml" then "gmp" else "sml"),SOME "invalid"]) [false,true]) modes
        fun rest ()=
          let val ()=if not native then () else
                let val stack=IntInfChecks.compile c "fork-stack" (source c "hardening" "fork") "stack" ["--allow-prim"]
                    val exe=path c "fork-native"
                    val result=invoke "native-compile" [] [fromRoot "bin/runeopt",stack,"-o",exe]
                    val ()=success result
                    fun run emulated inherited=output (invoke "native-fork" [("RUNEVM_INTINF",inherited),
                         ("RUNEVM_OPTIONS","--intinf=sml" ^ (if emulated then " --emulate-fork" else ""))] [exe]) "child policy preserved\nparent pass\n"
                in List.app (fn emulated => List.app (run emulated) ["gmp","invalid"]) [false,true] end
              val mode=if gmp then "gmp" else "sml"
              val cases=object (field "primitive_messages" (fixture "hardening"))
              fun primitive (name,message)=
                if not gmp andalso not (List.exists (fn x => x=name) ["operation","boolean","unit","bitcount","div-negative-zero","div-leading-zero","exponent"]) then () else
                let val program=compile name "registers"
                in rejected (invoke name [] [#vm c,"--intinf=" ^ mode,"--gc-stress","1",program]) (string message) end
              val ()=List.app primitive cases
              val zero=compile "div-zero" "registers"
              val ()=output (invoke "zero-divisor" [] [#vm c,"--intinf=" ^ mode,"--intinf-gmp-memory","1",zero]) "Div before GMP\n"
              val decimal=compile "decimal-primitive" "registers"
              val ()=if not gmp then () else
                let val result=invoke "decimal" [] [#vm c,"--intinf=gmp","--gc-stress","1","--gc-verify","--intinf-stats",decimal]
                    val ()=output result "0 18446744073709551615\n"
                    val ()=need (String.isSubstring "0 GMP live" (#errors result),"decimal primitive leaked GMP memory")
                    val large=compile "decimal-limits" "registers"
                    fun limit (flags,message)=let val result=invoke "decimal-limit" [] ([#vm c,"--intinf=gmp"] @ flags @ [large])
                                               in rejected result message; need (#output result="","decimal limit printed output") end
                in List.app limit [(["--intinf-max-bits","128"],"intinf magnitude limit exceeded"),
                                   (["--intinf-gmp-memory","256"],"intinf GMP memory limit exceeded")] end
              val result=invoke "decimal-unavailable" [] [#vm c,"--intinf=sml",decimal]
              val ()=rejected result "GMP backend is unavailable"
              val ()=need (#output result="","unavailable decimal backend printed output")
              val image=path c "policy.img"
              val writer=compile "policy" "registers"
              val ()=output (invoke "policy-save" [] [#vm c,writer]) "saved\n"
              val bytes=CachePlant.binary image
              val start=case CharVector.findi (fn (_,ch) => ch = #"\000") bytes of SOME (i,_) => i+1 | NONE => raise Failed "image header is not terminated"
              val ()=need (size bytes >= start+68,"saved policy header is truncated")
              fun patch name offset width value=
                let fun encode (0,_)="" | encode (n,value)=str (Char.chr (IntInf.toInt (IntInf.mod (value,256)))) ^ encode (n-1,IntInf.div (value,256))
                    val file=path c (name ^ ".img")
                in CachePlant.writeBinary file (String.substring (bytes,0,start+offset) ^ encode (width,value) ^ String.extract (bytes,start+offset+width,NONE));file end
              fun invalid (name,offset,width,value,message)=rejected (invoke name [] [#vm c,"--restore",patch name offset width value]) message
              val ()=List.app invalid [("mode",28,4,3,"bad IntInf policy"),("stats",32,4,2,"bad IntInf policy"),
                   ("bits-zero",52,8,0,"bad IntInf limits"),("bits-large",52,8,1073741823,"bad IntInf limits"),("memory-zero",60,8,0,"bad IntInf limits")]
              val wide=patch "memory-wide" 60 8 (valOf (IntInf.fromString "18446744073709551615"))
              val result=invoke "wide-saved-cap" [] [#vm c,"--intinf-gmp-memory","128","--intinf-stats","--restore",wide]
              val ()=output result "restored\n"
              val ()=need (String.isSubstring "GMP memory limit 128," (#errors result),"restoring did not narrow the saved memory cap")
              val allocation=ref [] : string list ref
              val ()=need (exists allocationTest,"missing IntInf allocation fixture: " ^ allocationTest)
              fun alloc mode=if !allocation=["unavailable"] then () else
                let val result=invoke ("allocation-" ^ mode) [] [allocationTest,mode]
                in if #status result=77 then (allocation := ["unavailable"]; say "SKIP allocation failures: GMP-free fixture\n") else
                     (need (#status result=(if mode="success" then 0 else 2) andalso
                            (mode="success" orelse String.isSubstring "intinf GMP allocation failed" (#errors result)),"allocation failure policy differs: " ^ mode);
                      allocation := !allocation @ [mode]) end
              val ()=List.app alloc ["success","malloc","realloc"]
              val report=Json.Object [("subprocesses",Json.Number (Int.toString (!(#sequence c)))),("result",Json.String "pass"),
                    ("native",Json.Bool native),("has_gmp",Json.Bool gmp),("allocation_checks",Json.Array (List.map Json.String (!allocation)))]
          in write (path c "report.json",Json.encode report ^ "\n") end
        val ()=if forkOnly then () else rest ()
    in say ("PASS IntInf hardening: " ^ Int.toString (!(#sequence c)) ^ " bounded subprocesses\n") end
end
