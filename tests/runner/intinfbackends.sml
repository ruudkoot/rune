(* One bytecode corpus across backend selection, all JIT tiers, finite
   magnitude/memory policies and cross-backend image restoration. *)
structure IntInfBackends =
struct
  open IntInfChecks
  fun one (c : context) () =
    let val gmp = hasGMP c
        val backends = (if gmp then [("gmp",#vm c)] else []) @ [("sml",#vm c),("auto",#smlVM c)]
        val bytecode = semantic c (#smlVM c) ["--intinf=sml"]
        fun tier "off" = ["--jit=off"] | tier level = ["--jit=all","--jit-tier=" ^ level]
        val counts = ref [] : ((string * string) * string) list ref
        fun mode (mode,vm) =
          let fun run level =
                let val result = invoke c vm mode bytecode (["--count"] @ tier level) 101
                    val () = output result "current: 1154 checks\noracle: 1154 checks\n"
                    val () = correctStats result (mode="gmp")
                    val count = case List.find (String.isPrefix "runevm: count: ") (lines (#errors result)) of SOME line => String.extract (line,size "runevm: count: ",NONE) | NONE => raise Failed "missing IntInf instruction counts"
                in counts := ((mode,level),count) :: !counts end
              val () = List.app run ["off","1","2"]
              val values = List.map #2 (List.filter (fn ((name,_),_) => name=mode) (!counts))
          in need (List.all (fn value => value=hd values) values,"IntInf counts vary by JIT tier") end
        val () = List.app mode backends
        fun count mode = #2 (valOf (List.find (fn ((name,tier),_) => name=mode andalso tier="off") (!counts)))
        val () = need (count "sml"=count "auto","GMP-free VM counts differ from forced SML")
        fun compile name = IntInfChecks.compile c name (source c "backends" name) "registers" []
        val pairs = compile "rooted-pairs"
        val () = List.app (fn (mode,vm) => List.app (fn level => output (invoke c vm mode pairs (tier level) 1) "rooted pairs pass\n") ["off","1","2"]) backends
        val special = compile "special"
        val failures = List.map (fn name => (name,compile name)) ["shift","power","multiply","carry","parse"]
        fun magnitude flags program (mode,vm) =
          let val result = invoke c vm mode program flags 1
          in rejected result "intinf magnitude limit exceeded";
             need (#output result="" andalso not (String.isSubstring "uncaught exception Overflow" (#errors result)),"IntInf magnitude refusal became output or an SML exception") end
        val () = List.app (fn (mode,vm) =>
            (output (invoke c vm mode special ["--intinf-max-bits","128"] 1) "special cases pass\n";
             List.app (fn (_,program) => magnitude ["--intinf-max-bits","128"] program (mode,vm)) failures)) backends
        val () = if not gmp then () else rejected (invoke c (#vm c) "gmp" (#2 (valOf (List.find (fn (name,_) => name="multiply") failures)))
                                      ["--intinf-gmp-memory","1"] 1) "intinf GMP memory limit exceeded"
        val () = rejected (invoke c (#smlVM c) "gmp" special [] 1) "GMP backend is unavailable"
        val paths = compile "budget-paths"
        val budgetFailures = List.map compile ["small-product","packed-carry","single-digit-product"]
        val () = List.app (fn (mode,vm) =>
             (output (invoke c vm mode paths ["--intinf-max-bits","65"] 1) "65-bit paths pass\n";
              List.app (fn program => magnitude ["--intinf-max-bits","65"] program (mode,vm)) budgetFailures)) backends
        val image = path c "world.img"
        val world = compile "world"
        val writers = (if gmp then [("gmp",#vm c)] else []) @ [("sml",#smlVM c)]
        fun writer (mode,vm) limit =
          let val () = output (invoke c vm mode world ["--intinf-max-bits",Int.toString limit] 1) "saved\n"
              fun reader (mode,vm) =
                let val result = invoke c vm mode image ["--intinf-max-bits","1024","--restore"] 1
                    val () = if limit=1024 then (output result "restored\n";
                              let val calls = Option.mapPartial IntInf.fromString (#1 (stats result))
                              in need (case calls of SOME n => (n>0)=(mode="gmp") | NONE => false,"restored image selected wrong arithmetic backend") end)
                             else rejected result "intinf magnitude limit exceeded"
                in rejected (invoke c vm mode image ["--intinf-max-bits","64","--restore"] 1) "intinf magnitude limit exceeded" end
          in List.app reader backends end
        val () = List.app (fn writerMode => List.app (writer writerMode) [1024,256]) writers
        val formatted = compile "format-world"
        fun formatting writer =
          let val (mode,vm)=writer
              val ()=output (invoke c vm mode formatted ["--intinf-max-bits","1024"] 1) "saved\n"
              fun reader (mode,vm) limit =
                let val result=invoke c vm mode image ["--intinf-max-bits",Int.toString limit,"--restore"] 1
                in if limit=512 then
                     (output result "formatted\n"; let val calls=Option.mapPartial IntInf.fromString (#1 (stats result))
                      in need (case calls of SOME n => (n>0)=(mode="gmp") | NONE => false,"formatting selected the writer's backend") end)
                   else (rejected result "intinf magnitude limit exceeded"; need (#output result="","restored formatting ignored stricter limit")) end
          in List.app (fn backend => List.app (reader backend) [512,128]) backends end
        val ()=List.app formatting writers
        val report=Json.Object [("checks",Json.String "pass"),("subprocesses",Json.Number (Int.toString (!(#sequence c)))),
             ("bytecode_sha256",Json.String (Hex.fromBytes (Sha256.digest (CachePlant.binary bytecode)))),
             ("counts",Json.Object (List.map (fn (mode,_) => (mode,Json.String (count mode))) backends)),("has_gmp",Json.Bool gmp),
             ("stress",Json.Bool (#stress c)),("vm_options",Json.String (String.concatWith " " (#vmOptions c)))]
        val ()=write (path c "report.json",Json.encode report ^ "\n")
    in say ("PASS IntInf backends: " ^ Int.toString (!(#sequence c)) ^ " bounded subprocesses\n") end
end
