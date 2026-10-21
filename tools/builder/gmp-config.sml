structure BuildGMPConfig =
struct
  open BuildCommon
  structure O=BuildOptions
  val probe="\n#include <stdio.h>\n#include <gmp.h>\nint main(void) {\n  unsigned major = 0, minor = 0, patch = 0;\n  printf(\"%d.%d.%d\\n%s\\n%d\\n%d\\n%d\\n\", __GNU_MP_VERSION,\n    __GNU_MP_VERSION_MINOR, __GNU_MP_VERSION_PATCHLEVEL, gmp_version,\n    GMP_NUMB_BITS, mp_bits_per_limb, GMP_NAIL_BITS);\n  /* Reject unsupported ABI metadata before using arithmetic objects. */\n  if (__GNU_MP_VERSION < 6 || (__GNU_MP_VERSION == 6 && __GNU_MP_VERSION_MINOR < 3) ||\n      sscanf(gmp_version, \"%u.%u.%u\", &major, &minor, &patch) != 3 ||\n      major != __GNU_MP_VERSION || (major == 6 && minor < 3) ||\n      GMP_NUMB_BITS != mp_bits_per_limb || GMP_NAIL_BITS != 0) return 0;\n  mpz_t x; mpz_init_set_ui(x, 17); mpz_mul(x, x, x);\n  if (mpz_cmp_ui(x, 289)) return 1;\n  mpz_clear(x);\n  return 0;\n}\n"
  fun canonical value =case value of Json.Object entries => Json.Object (List.map (fn (key,v) => (key,canonical v)) (sort (fn ((a,_),(b,_)) => a<b) entries))
       | Json.Array values => Json.Array (List.map canonical values) | _ => value
  fun asciiString source =
    let fun hex c="\\u" ^ StringCvt.padLeft #"0" 4 (String.map Char.toLower (Int.fmt StringCvt.HEX c))
        fun one c=case c of 34 => "\\\"" | 92 => "\\\\" | 8 => "\\b" | 12 => "\\f" | 10 => "\\n" | 13 => "\\r" | 9 => "\\t"
            | _ => if c>=32 andalso c<127 then Utf8.encode c else if c<=65535 then hex c else hex (55296+(c-65536) div 1024) ^ hex (56320+(c-65536) mod 1024)
    in "\"" ^ String.concat (List.map one (Utf8.explode source)) ^ "\"" end
  fun metadataJSON value=case value of Json.Null => "null" | Json.Bool b => if b then "true" else "false" | Json.Number n => n | Json.String s => asciiString s
       | Json.Array values => "[" ^ String.concatWith ", " (List.map metadataJSON values) ^ "]"
       | Json.Object entries => "{" ^ String.concatWith ", " (List.map (fn (key,value) => asciiString key ^ ": " ^ metadataJSON value) entries) ^ "}"
  fun supported version=case version of major::minor::_ => major>6 orelse (major=6 andalso minor>=3) | _ => false
  fun main args =
    let val options=O.parse [("--mode",O.Value),("--cc",O.Value),("--cflags",O.Value),("--prefix",O.Value),("--out",O.Value),("--runner",O.Value)] [] args
        val mode=O.require options "--mode" val cc=O.get options "--cc" "cc" val cflags=O.get options "--cflags" "" val prefix=O.get options "--prefix" "" val runner=O.get options "--runner" ""
        val caller=OS.FileSys.getDir ()
        val out=O.require options "--out" val ()=mkdirs out
        val ()=need (List.exists (fn choice => mode=choice) ["auto","yes","no"],"GMP mode must be auto, yes or no")
        val record=ref (Json.Object [("mode",str mode),("cc",str cc),("cflags",str cflags),("prefix",str prefix),("runner",str runner),("enabled",Json.Bool false)])
        fun put key value=record:=set key value (!record)
        val cpp=ref [] : string list ref val libs=ref [] : string list ref val reason=ref "disabled by GMP=no" val sequence=ref 0
        fun run command =
          let val ()=sequence:= !sequence+1 val result=execute caller (out ^ "/observation-" ^ Int.toString (!sequence)) 60.0 command (Posix.ProcEnv.environ ())
          in if #status result=0 then trim (#output result) else raise Failed (let val message=trim (#errors result) in if message="" then "command failed: " ^ BuildCommon.command command else message end) end
        fun configure () =
          let val provenance=if prefix<>"" then
                 let val path=resolved prefix val header=path ^ "/include/gmp.h" val library=path ^ "/lib/libgmp.a"
                     val ()=List.app (fn file => need (exists file andalso not (isDir file),"missing " ^ file)) [header,library]
                     val ()=(cpp:=["-I" ^ path ^ "/include"];libs:=[library])
                     val dependency=if exists (path ^ "/rune-gmp.json") then readJson (path ^ "/rune-gmp.json") else Json.Null
                     val ()=List.app (fn (label,file) => let val digest=hash file in put (label ^ "_sha256") (str digest);
                         if dependency=Json.Null then () else need (digest=text (field (label ^ "_sha256") dependency),"GMP " ^ label ^ " differs from its provisioning record") end) [("header",header),("library",library)]
                     val ()=put "dependency" dependency
                 in if dependency=Json.Null then "checked local prefix" else "pinned " ^ text (field "sha256" (field "config" dependency)) end
               else
                 let val pkg=(SOME (words (run ["pkg-config","--cflags","gmp"]),words (run ["pkg-config","--libs","gmp"]),run ["pkg-config","--modversion","gmp"]) handle Failed _ => NONE | OS.SysErr _ => NONE | BuildIO.TimedOut _ => NONE)
                     val ()=case pkg of SOME (c,l,v) => (cpp:=c;libs:=l;put "pkg_config_version" (str v)) | NONE => (cpp:=[];libs:=["-lgmp"];put "pkg_config_version" Json.Null)
                 in "checked system installation; source and build options not supplied" end
              val ()=write (out ^ "/probe.c",probe)
              val command=words cc @ words cflags @ !cpp @ [out ^ "/probe.c"] @ !libs @ ["-o",out ^ "/probe.exe"]
              val ()=put "probe_command" (strings command) val _=run command
              val output=List.map trim (lines (run (words runner @ [resolved (out ^ "/probe.exe")])))
              val ()=need (length output=5,"invalid GMP probe metadata")
              val h=version (List.nth (output,0)) val l=version (List.nth (output,1))
              val ()=List.app (fn (key,value) => put key value)
                 [("header_version",str (List.nth (output,0))),("library_version",str (List.nth (output,1))),("header_limb_bits",number (integer (List.nth (output,2)))),("library_limb_bits",number (integer (List.nth (output,3)))),("nail_bits",number (integer (List.nth (output,4))))]
              val mismatch="unsupported or mismatched GMP header/library: [" ^ String.concatWith ", " (List.map (fn s => "'" ^ s ^ "'") output) ^ "]"
              val ()=need (supported h andalso supported l andalso hd h=hd l andalso List.nth (output,2)=List.nth (output,3) andalso List.nth (output,4)="0",mismatch)
              val dependency=member "dependency" (!record)
              val configured=if dependency=Json.Null then Json.Null else member "configured" dependency
              val target=if configured=Json.Null orelse member "host" configured=Json.Null orelse text (member "host" configured)="" then run (words cc @ words cflags @ ["-dumpmachine"]) else text (field "host" configured)
              val compiler=case lines (run (words cc @ ["--version"])) of first::_ => first | [] => raise Failed "compiler printed no version"
              val ()=List.app (fn (key,value) => put key value) [("enabled",Json.Bool true),("limb_bits",number (integer (List.nth (output,2)))),("provenance",str provenance),("target",str target),("compiler",str compiler)]
          in reason:=provenance end
        fun failure message=(reason:=message;if mode="yes" then raise Failed ("GMP=yes: " ^ message) else (cpp:=[];libs:=[]))
        val ()=if mode="no" then () else (configure () handle Failed why => failure why | Usage why => failure why | OS.SysErr (why,_) => failure why | IO.Io {name,cause,...} => failure (name ^ ": " ^ General.exnMessage cause) | Json.Syntax (_,why) => failure why | BuildIO.TimedOut _ => failure "GMP probe timed out")
        val ()=(put "reason" (str (!reason));put "cppflags" (strings (!cpp));put "ldlibs" (strings (!libs)))
        val dependency=member "dependency" (!record)
        val options=if dependency=Json.Null then Json.Object [("unknown",Json.Bool true)] else Json.Object [("requested",field "config" dependency),("configured",getOpt (Json.member ("configured",dependency),Json.Object []))]
        val provenance=getOpt (Option.map text (Json.member ("provenance",!record)),!reason)
        val target=getOpt (Option.map text (Json.member ("target",!record)),"unavailable")
        val ()=json (out ^ "/config.json") (!record)
        val ()=atomic (out ^ "/config.h") ("#define RUNE_HAVE_GMP " ^ (if boolean (field "enabled" (!record)) then "1" else "0") ^ "\n#define RUNE_GMP_PROVENANCE " ^ asciiString provenance ^ "\n#define RUNE_GMP_TARGET " ^ asciiString target ^ "\n#define RUNE_GMP_OPTIONS " ^ asciiString (metadataJSON (canonical options)) ^ "\n")
        val ()=atomic (out ^ "/config.mk") ("GMP_CPPFLAGS := " ^ BuildCommon.command (!cpp) ^ "\nGMP_LDLIBS := " ^ BuildCommon.command (!libs) ^ "\n")
    in say ("GMP: " ^ (if boolean (field "enabled" (!record)) then "enabled: " else "SML fallback: ") ^ !reason ^ "\n");0 end
end
