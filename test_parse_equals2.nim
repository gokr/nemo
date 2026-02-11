import std/[unittest, tables, sequtils, strutils]
import src/harding/core/types
import src/harding/core/scheduler
import src/harding/interpreter/vm
import src/harding/interpreter/objects
import src/harding/parser/lexer
import src/harding/parser/parser

discard initCoreClasses()

let ctx = newSchedulerContext()
var interp = ctx.mainProcess.getInterpreter()

# Test parsing Object>>= other
let source = """
Object>>= other [
  ^ self == other
]
"""

let tokens = lex(source)
echo "Tokens:"
for i, tok in tokens:
  echo "  ", i, ": ", tok.kind, " = '", tok.value, "'"

echo ""
var p = initParser(tokens)
let nodes = p.parseStatements()
echo "Parse error: '", p.errorMsg, "'"
echo "Has error: ", p.hasError
echo "Nodes: ", nodes.len
for node in nodes:
  if node of MessageNode:
    let msg = cast[MessageNode](node)
    var receiverName = "unknown"
    if msg.receiver of IdentNode:
      receiverName = cast[IdentNode](msg.receiver).name
    echo "  Message: receiver=", receiverName, " selector='", msg.selector, "' args=", msg.arguments.len
    for i, arg in msg.arguments:
      if arg of IdentNode:
        echo "    arg ", i, ": ", cast[IdentNode](arg).name
  else:
    echo "  Node kind: ", node.kind

echo ""
echo "Trying to eval..."
let (results, err) = interp.evalStatements(source)
echo "Error: '", err, "'"
echo "Results: ", results.len
if results.len > 0:
  echo "Last result kind: ", results[^1].kind

# Check if Object has = method after eval
echo ""
echo "Checking if Object has = method after eval:"
let objClass = interp.globals[]["Object"]
if objClass.kind == vkClass:
  echo "Has '=': ", objClass.classVal.methods.hasKey("=")
