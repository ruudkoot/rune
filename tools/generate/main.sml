structure GenerateMain =
struct
  fun rewriteResult kind args =
    let fun table file=List.map (fn line => case MeasureCommon.tabs line of key::value::_ => (key,value) | _ => raise MeasureCommon.Failed "invalid extension settings row") (Sh.lines (Sh.read file))
        fun parse settings file []=(settings,file)
          | parse (s:GenerateRewrites.settings) file ("--table"::v::rest)=parse {table=SOME v,typed= #typed s,consts= #consts s,ctypes= #ctypes s,ambiguous= #ambiguous s} file rest
          | parse s file ("--typed"::v::rest)=parse {table= #table s,typed=Sh.lines (Sh.read v),consts= #consts s,ctypes= #ctypes s,ambiguous= #ambiguous s} file rest
          | parse s file ("--consts"::v::rest)=parse {table= #table s,typed= #typed s,consts=table v,ctypes= #ctypes s,ambiguous= #ambiguous s} file rest
          | parse s file ("--ctypes"::v::rest)=parse {table= #table s,typed= #typed s,consts= #consts s,ctypes=table v,ambiguous= #ambiguous s} file rest
          | parse s file ("--ambiguous"::v::rest)=parse {table= #table s,typed= #typed s,consts= #consts s,ctypes= #ctypes s,ambiguous=Sh.lines (Sh.read v)} file rest
          | parse s "" (v::rest)=parse s v rest | parse _ _ _=raise MeasureCommon.Usage "rewrite-HOST [--table FILE] [SETTINGS] SOURCE"
        val (settings,file)=parse GenerateRewrites.empty "" args
        val ()=MeasureCommon.need (file<>"", "rewrite source is required")
        val f=case kind of "mlkit" => GenerateRewrites.mlkit | "mlton" => GenerateRewrites.mlton | "polyml" => GenerateRewritePoly.main | "smlnj" => GenerateRewriteNJ.main | "prims" => (fn settings => fn file => GenerateMLtonPrims.make settings (Sh.lines (GenerateText.required file))) | _ => raise Fail "unknown host rewrite"
    in f settings file end
  fun rewrite kind args=(Sh.say (rewriteResult kind args);0)
  fun flatten (flat::out::basis::options)=
    let val ()=MeasureCommon.need (Sh.exists flat,"missing flat source list")
        val out=GenerateXC2.output out val basis=Sh.fromRoot basis
        val rewrite=case options of [] => GenerateText.required | host::args => (fn file => rewriteResult host (args @ [file]))
    in ignore (GenerateFlatten.generate (GenerateFlatten.readFlat flat) out basis rewrite);0 end
    | flatten _=raise MeasureCommon.Usage "flatten FLAT OUTDIR BASIS [HOST SETTINGS...]"
  fun main ["--help"]=(Sh.say "rune-generate MODE [ARGS]\nSee tools/generate/README.md for generator modes and input contracts.\n";0)
    | main ("flatten"::args)=flatten args
    | main ("mlton-prims"::args)=rewrite "prims" args
    | main ("inventory"::args)=GenerateInventory.main args
    | main ("structures"::args)=GenerateStructures.main args
    | main ("polyml-order"::args)=GenerateXC2Poly.orderCLI args
    | main ("xc2-polyml"::args)=GenerateXC2Poly.main args
    | main ("xc2-smlnj-legacy"::args)=GenerateXC2NJ.main (Sh.env ("XC2_SMLNJ_PORT","smlnj-legacy")) args
    | main ("xc2-smlnj-dev"::args)=GenerateXC2NJ.main "smlnj-dev" args
    | main ("xc2-mlton"::args)=GenerateXC2.mlton args
    | main ("xc2-mlkit"::args)=GenerateXC2.mlkit args
    | main ("rewrite-mlkit"::args)=rewrite "mlkit" args
    | main ("rewrite-mlton"::args)=rewrite "mlton" args
    | main ("rewrite-polyml"::args)=rewrite "polyml" args
    | main ("rewrite-smlnj"::args)=rewrite "smlnj" args
    | main ("basis-signatures"::args)=GenerateSignatures.main args
    | main ("unicode"::args)=GenerateUnicode.main args
    | main ("mlb-flatten"::args)=GenerateMLB.main args
    | main ("top-structures"::args)=GenerateFlatten.top args
    | main ("trim-lib"::args)=GenerateFlatten.trimLib args
    | main ("host-basis"::args)=GenerateHostBasis.main args
    | main ("annotations"::args)=GenerateAnnotations.main args
    | main ("perf"::args)=GeneratePerf.main args
    | main ("fxp"::args)=GenerateFXP.main args
    | main ("entities"::args)=GenerateFixtures.entities args
    | main ("digest-vectors"::args)=GenerateFixtures.digest args
    | main _=raise MeasureCommon.Usage "rune-generate perf|fxp|entities|digest-vectors [ARGS]"
end
val ()=let val status=GenerateMain.main (CommandLine.arguments ())
       in if status=0 then () else Posix.Process.exit (Word8.fromInt status) end
       handle e => (Sh.say ("generator: " ^ (case e of MeasureCommon.Failed text => text | MeasureCommon.Usage text => text | Fail text => text | _ => General.exnMessage e) ^ "\n");
                    Posix.Process.exit (case e of MeasureCommon.Usage _ => 0w2 | _ => 0w1))
