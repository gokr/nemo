import src/harding/core/types
import src/harding/core/scheduler
import src/harding/interpreter/vm
import src/harding/interpreter/objects
import std/tables

discard initCoreClasses()

let ctx = newSchedulerContext()
var interp = ctx.mainProcess.getInterpreter()

# Check if Object has = method
echo "Checking Object methods:"
let objClass = interp.globals[]["Object"]
if objClass.kind == vkClass:
  echo "Has '=': ", objClass.classVal.methods.hasKey("=")
  echo "Has '==': ", objClass.classVal.methods.hasKey("==")

# Test string comparison
echo ""
echo "Testing string comparison:"
let result = interp.evalStatements("""
  Result := "hello" = "hello"
""")
echo "Error: '", result[1], "'"
echo "Results: ", result[0].len
if result[0].len > 0:
  echo "Last result kind: ", result[0][^1].kind
  if result[0][^1].kind == vkBool:
    echo "Last result boolVal: ", result[0][^1].boolVal
