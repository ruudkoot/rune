module B0=Bytes
module S0=String
module NativeSys=Sys
let hook=ref(fun(_:Obj.t)->())
let copy_hook=ref(fun(_:B0.t)->())
let blit_hook=ref(fun(_:B0.t)->())
let iter_hook=ref(fun(_:int)->())
module Sys=struct include NativeSys
 let opaque_identity value=(!hook)(Obj.repr value);NativeSys.opaque_identity value
end
module Bytes=struct include B0
 let copy value=let result=B0.copy value in (!copy_hook)result;result
 let blit source start dest offset length=B0.blit source start dest offset length;(!blit_hook)dest
 let iter f input=let calls=ref 0 in B0.iter(fun c->incr calls;f c)input;(!iter_hook)!calls
end
module String=struct include S0
 let blit source start dest offset length=S0.blit source start dest offset length;(!blit_hook)dest
 let iter f input=let calls=ref 0 in S0.iter(fun c->incr calls;f c)input;(!iter_hook)!calls
end
let test_bytes = Bytes.of_string
  "In Department condita sicut Laboratory Mathematica in manu Lenard, John \
   Jones May XIV MCMXXXVII, quamquam is did non adepto recte statutum usque \
   post Belli Orbis Terrarum II. Laboratorium Septentrionalis Nova erat \
   proque domo longis Wing est pristini Advertising School, in Novum Site. In \
   die qua fundata est, cum in animo sit computing ministerium providere ad \
   communem usum, et quod a centro est, in development of Universitatis elit \
   computational. Et Diplomatis Cambridge in Computer Science est mundi \
   primum doceri utique postgraduate in computing, incipiens in MCMLIII."

let bytes_get iterations =
  let length = Bytes.length test_bytes in
  for i = 1 to iterations do
    ignore (Sys.opaque_identity (Bytes.get test_bytes (i mod length)))
  done

let bytes_set iterations =
  let copy = Bytes.copy test_bytes in
  let copy_length = Bytes.length copy in
  for i = 1 to iterations do
    Sys.opaque_identity (Bytes.set copy (i mod copy_length) ' ')
  done

let bytes_cat iterations =
  let s = Bytes.of_string "I AM A FISH" in
  for i = 1 to iterations do
    ignore (Sys.opaque_identity (Bytes.cat s test_bytes))
  done

let bytes_sub iterations =
  let length = Bytes.length test_bytes in
  for i = 1 to iterations do
    let i_start = i mod (length - 2) in
    ignore (Sys.opaque_identity (Bytes.sub test_bytes i_start 2))
  done

let bytes_blit iterations =
  let length = Bytes.length test_bytes in
  for i = 1 to iterations do
    let dst = Bytes.make 32 ' ' in
    Bytes.blit test_bytes (i mod (length - 32)) dst 0 32
  done

let bytes_concat iterations =
  let fish = List.map Bytes.of_string ["I"; "AM"; "A"; "FISH"] in
  let delim = Bytes.of_string " " in
  for i = 1 to iterations do
    ignore (Sys.opaque_identity (Bytes.concat delim fish))
  done

let bytes_iter iterations =
  for i = 1 to iterations do
    Bytes.iter (fun c -> ()) test_bytes
  done

let bytes_map iterations =
  for i = 1 to iterations do
    ignore (Sys.opaque_identity (Bytes.map (fun c -> '!') test_bytes))
  done

let bytes_trim iterations =
  let bytes_needing_trimming = Bytes.of_string "We need a trim\n\n\n\n\n" in
  for i = 1 to iterations do
    ignore (Sys.opaque_identity (Bytes.trim bytes_needing_trimming))
  done

let bytes_index iterations =
  for i = 1 to iterations do
    ignore (Sys.opaque_identity (Bytes.index test_bytes 'r'))
  done

let bytes_contains iterations =
  for i = 1 to iterations do
    ignore (Sys.opaque_identity (Bytes.contains test_bytes 'r'))
  done

let bytes_uppercase_ascii iterations =
  for i = 1 to iterations do
    ignore (Sys.opaque_identity (Bytes.uppercase_ascii test_bytes))
  done

