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
for tok in tokens:
  echo "  ", tok.kind, ": '", tok.value, "'"

echo ""
var p = initParser(tokens)
let nodes = p.parseStatements()
echo "Parse error: '", p.errorMsg, "'"
echo "Has error: ", p.hasError
echo "Nodes: ", nodes.len
for node in nodes:
  echo "  Node kind: ", node.kind
