structure GeneratedScalars : GENERATEDSCALARS =
struct
  type session=unit
  fun openSession {libraries}=()
  fun closeSession ()=()
  fun add () {first,second}=first+second
  fun bits () bits=Word32.xorb(bits,0wx80000000)
  fun fraction () value=value+0.25
  fun invert () value=not value
end
_export structure GeneratedScalars : GENERATEDSCALARS = GeneratedScalars
