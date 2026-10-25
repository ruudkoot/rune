(* Malformed primitive arguments, backend policy across fork, saved-policy
   fields and allocation failures. Fixtures reproduce invalid public inputs. *)
structure IntInfHardening =
struct
  open IntInfChecks
  (* Independent image-15 prefix reader. Keep the named field sequence beside
     the format guard: a new image version must be reviewed, not patched at
     offsets inherited from an older layout. Fields use little-endian bytes. *)
  fun savedPolicyLayout bytes =
    let val start=case CharVector.findi(fn(_,ch)=>ch= #"\000")bytes of
            SOME(i,_)=>i+1 | NONE=>raise Failed "image header is not terminated"
        val magic=String.substring(bytes,0,start-1)
        val magicPrefix="runevm image 15 isa "
        val ()=need(size magic=size magicPrefix+8 andalso String.isPrefix magicPrefix magic,
                    "saved policy fixture requires image format 15")
        val ()=need(CharVector.all Char.isHexDigit(String.extract(magic,size magicPrefix,NONE)),
                    "unsupported saved policy image fingerprint")
        val cursor=ref 0
        fun field name width=
          let val offset= !cursor
              val ()=need(width<=size bytes-start-offset,"saved policy header is truncated at " ^ name)
          in cursor:=offset+width;offset end
        fun unsigned offset width=
          let fun read(0,_,_,value)=value
                | read(left,at,scale,value)=read(left-1,at+1,scale*256,
                    value+IntInf.fromInt(Char.ord(String.sub(bytes,start+at)))*scale)
          in read(width,offset,1,0) end
        val kind=field "kind" 4
        val floor=field "foreign identity floor" 8
        val _=field "trace" 4
        val _=field "stats" 4
        val _=field "count" 4
        val _=field "emulated fork" 4
        val _=field "rounding mode" 4
        val _=field "heap fill" 4
        val mode=field "IntInf mode" 4
        val stats=field "IntInf statistics" 4
        val _=field "heap limit" 8
        val _=field "equality work" 8
        val bits=field "IntInf magnitude limit" 8
        val memory=field "IntInf memory limit" 8
        val ()=need(unsigned kind 4=1,"saved policy fixture is not a Runtime.save image")
        val ()=need(unsigned floor 8>0,"saved policy image has an invalid foreign identity floor")
        val ()=need(unsigned mode 4=0 andalso unsigned stats 4=0,"saved policy image is not canonical")
    in {start=start,mode=mode,stats=stats,bits=bits,memory=memory,finish= !cursor} end
  fun one (c : context) forkOnly native allocationTest () =
    let val gmp=hasGMP c
        (* without the lint that bin/rune-test asks of every compile
           (RUNE_LINT): the fixtures call primitives at the wrong types on
           purpose, which it refuses, for the runtime to refuse them *)
        fun compileAs (name, from, target)=IntInfChecks.compileWith [("RUNE_LINT","")] c name (source c "hardening" from) target ["--allow-prim"]
        fun compile name target=compileAs (name, name, target)
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
                let val stack=compileAs ("fork-stack", "fork", "stack")
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
              val layout=savedPolicyLayout bytes
              val start= #start layout
              fun patch name offset width value=
                let fun encode (0,_)="" | encode (n,value)=str (Char.chr (IntInf.toInt (IntInf.mod (value,256)))) ^ encode (n-1,IntInf.div (value,256))
                    val file=path c (name ^ ".img")
                in CachePlant.writeBinary file (String.substring (bytes,0,start+offset) ^ encode (width,value) ^ String.extract (bytes,start+offset+width,NONE));file end
              fun invalid (name,offset,width,value,message)=rejected (invoke name [] [#vm c,"--restore",patch name offset width value]) message
              val ()=List.app invalid [("mode",#mode layout,4,3,"bad IntInf policy"),("stats",#stats layout,4,2,"bad IntInf policy"),
                   ("bits-zero",#bits layout,8,0,"bad IntInf limits"),("bits-large",#bits layout,8,1073741823,"bad IntInf limits"),
                   ("memory-zero",#memory layout,8,0,"bad IntInf limits")]
              val wide=patch "memory-wide" (#memory layout) 8 (valOf (IntInf.fromString "18446744073709551615"))
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
                    ("native",Json.Bool native),("has_gmp",Json.Bool gmp),("allocation_checks",Json.Array (List.map Json.String (!allocation))),
                    ("saved_policy_layout",Json.Object[("version",Json.Number "15"),("header_bytes",Json.Number(Int.toString start)),
                      ("mode",Json.Number(Int.toString(#mode layout))),("stats",Json.Number(Int.toString(#stats layout))),
                      ("bits",Json.Number(Int.toString(#bits layout))),("memory",Json.Number(Int.toString(#memory layout)))])]
          in write (path c "report.json",Json.encode report ^ "\n") end
        val ()=if forkOnly then () else rest ()
    in say ("PASS IntInf hardening: " ^ Int.toString (!(#sequence c)) ^ " bounded subprocesses\n") end
end
