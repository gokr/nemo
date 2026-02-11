import std/[unittest, tables, sequtils, strutils]
import src/harding/core/types
import src/harding/core/scheduler
import src/harding/interpreter/vm
import src/harding/interpreter/objects

discard initCoreClasses()

let ctx = newSchedulerContext()
var interp = ctx.mainProcess.getInterpreter()

# Test 1: Basic string comparison
echo "Test 1: Basic string comparison"
let result1 = interp.evalStatements("""
  Result := "hello" = "hello"
""")
echo "Error: '", result1[1], "'"
echo "Results length: ", result1[0].len
if result1[0].len > 0:
  echo "Last result kind: ", result1[0][^1].kind

echo ""

# Test 2: Processor fork and state
echo "Test 2: Processor fork and state"
let result2 = interp.evalStatements("""
  P := Processor fork: [42].
  State := P state.
  Result := State
""")
echo "Error: '", result2[1], "'"
echo "Results length: ", result2[0].len
if result2[0].len > 0:
  echo "Last result kind: ", result2[0][^1].kind
  if result2[0][^1].kind == vkString:
    echo "Last result strVal: ", result2[0][^1].strVal

echo ""

# Test 3: State comparison
echo "Test 3: State comparison"
let result3 = interp.evalStatements("""
  P := Processor fork: [42].
  IsReady := P state = "ready".
  Result := IsReady
""")
echo "Error: '", result3[1], "'"
echo "Results length: ", result3[0].len
if result3[0].len > 0:
  echo "Last result kind: ", result3[0][^1].kind
