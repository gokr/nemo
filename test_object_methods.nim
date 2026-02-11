import std/[unittest, tables, sequtils, strutils]
import src/harding/core/types
import src/harding/core/scheduler
import src/harding/interpreter/vm
import src/harding/interpreter/objects

discard initCoreClasses()

let ctx = newSchedulerContext()
var interp = ctx.mainProcess.getInterpreter()

# List all Object methods
echo "Object methods:"
let objClass = interp.globals[]["Object"]
if objClass.kind == vkClass:
  for name, _ in pairs(objClass.classVal.methods):
    echo "  - ", name

echo ""
echo "Does Object have '=': ", objClass.classVal.methods.hasKey("=")

# Try loading Object.hrd manually
echo ""
echo "Loading Object.hrd..."
let (_, err) = interp.evalStatements("""
  Object>>testMethod [ ^ 42 ]
""")
echo "Error: '", err, "'"

# Check again
echo ""
echo "After loading, does Object have 'testMethod': ", objClass.classVal.methods.hasKey("testMethod")
