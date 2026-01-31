import std/[tables, sequtils, logging]
import ../src/nimtalk/core/types
import ../src/nimtalk/interpreter/evaluator
import ../src/nimtalk/interpreter/objects

var interp = newInterpreter()
initGlobals(interp)
loadStdlib(interp)

addHandler(newConsoleLogger(lvlDebug))

echo "=== Test what self is inside block ==="
let r1 = interp.evalStatements("""
Integer>>test [
  | x |
  true ifTrue: [ x := self ].
  ^ x
].
5 test
""")
echo "Error: ", r1[1]
echo "Results count: ", r1[0].len
for i, res in r1[0]:
  echo "  Result[", i, "]: ", res
  if res.kind == vkObject:
    echo "    tags: ", res.objVal.tags
    echo "    isNimProxy: ", res.objVal.isNimProxy
    if res.objVal.isNimProxy and res.objVal.nimType == "int":
      echo "    nimValue: ", cast[ptr int](res.objVal.nimValue)[]
