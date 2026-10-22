structure BuildRuntimeRecord =
struct
  open BuildCommon
  structure O=BuildOptions
  fun main args =
    let val options=O.parse [("--vm",O.Value),("--cc",O.Value),("--cflags",O.Value),("--ldlibs",O.Value),("--config",O.Value),("--out",O.Value),("--sources",O.Many true),("--headers",O.Many true)] [] args
        val vm=BuildRuntimeInputs.executablePath (O.require options "--vm") val cc=words (O.require options "--cc") val flags=words (O.require options "--cflags")
        val config=O.require options "--config" val configuration=readJson (config ^ "/config.json") val sources=O.values options "--sources" val headers=O.values options "--headers"
        val output=O.require options "--out"
        val inputs=BuildRuntimeInputs.collect (OS.FileSys.getDir ()) cc flags (List.map text (array (field "cppflags" configuration))) (config ^ "/config.h") sources headers (output ^ ".dependencies")
        val record=Json.Object [("vm_file",str vm),("vm_sha256",str (hash vm)),("configuration",configuration),("cc",strings cc),("cflags",strings flags),("ldlibs",strings (words (O.get options "--ldlibs" "-lm"))),
             ("sources",strings sources),("headers",strings headers),("source_hashes",Json.Object (List.map (fn file => (file,str (hash file))) inputs))]
    in json output record;0 end
end
