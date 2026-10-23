structure GenerateFixtureShim =
struct
  val i=CParse.Named "int32_t"
  val d=CParse.Builtin "double"
  val u=CParse.Builtin "unsigned int"
  val pair=CParse.Named "rf_pair"
  val bits=CParse.Named "rf_bits"
  val source=ForeignShim.preamble["shim.h"] ^
    ForeignShim.call{name="runeffi_pair_make",foreign="rf_make_pair",result=pair,parameters=[i,d],indirectResult=true,indirectArguments=[false,false]} ^
    ForeignShim.call{name="runeffi_pair_total",foreign="rf_pair_total",result=d,parameters=[pair],indirectResult=false,indirectArguments=[true]} ^
    ForeignShim.call{name="runeffi_low",foreign="RF_LOW",result=u,parameters=[u],indirectResult=false,indirectArguments=[false]} ^
    ForeignShim.call{name="runeffi_twice",foreign="rf_inline_twice",result=CParse.Builtin "int",parameters=[CParse.Builtin "int"],indirectResult=false,indirectArguments=[false]} ^
    ForeignShim.call{name="runeffi_variadic_sum",foreign="rf_variadic",result=CParse.Builtin "int",
      parameters=[u,CParse.Builtin "short",CParse.Builtin "signed char"],indirectResult=false,indirectArguments=[false,false,false]} ^
    ForeignShim.call{name="runeffi_variadic_real",foreign="rf_variadic_real",result=d,
      parameters=[u,CParse.Builtin "float",CParse.Builtin "float"],indirectResult=false,indirectArguments=[false,false,false]} ^
    ForeignShim.field{name="runeffi_bits_low",aggregate=bits,path=["low"],ty=u,writable=true} ^
    ForeignShim.field{name="runeffi_bits_high",aggregate=bits,path=["high"],ty=u,writable=true} ^
    ForeignShim.field{name="runeffi_value_bits",aggregate=CParse.Named "rf_value",path=["bits"],ty=CParse.Named "uint64_t",writable=true} ^
    ForeignShim.field{name="runeffi_value_real",aggregate=CParse.Named "rf_value",path=["real"],ty=d,writable=true} ^
    ForeignShim.field{name="runeffi_pointer_value",aggregate=CParse.Named "rf_pointer_record",path=["value"],
      ty=CParse.Pointer{target=CParse.Builtin "void",qualifiers=[]},writable=true} ^
    ForeignShim.field{name="runeffi_pointer_callback",aggregate=CParse.Named "rf_pointer_record",path=["callback"],
      ty=CParse.typeName{tokens=CLex.scan{file="adapter-policy",text="int (*)(void *, int)"},predefinedTypes=[]},writable=true} ^
    String.concat(List.map(fn(name,ty)=>ForeignShim.field{name="runeffi_packed_" ^ name,aggregate=CParse.Named "rf_packed_bits",
      path=[name],ty=ty,writable=true})[("low",u),("high",u),("prefix",CParse.Builtin "unsigned char"),("tail",CParse.Builtin "unsigned char")])
  val ()=case CommandLine.arguments() of ["--runeffi-output",path]=>
      let val stream=TextIO.openOut path in TextIO.output(stream,source);TextIO.closeOut stream end
    | _=>TextIO.output(TextIO.stdOut,"RUNEFFI_SOURCE_BEGIN\n" ^ source ^ "RUNEFFI_SOURCE_END\n")
end
