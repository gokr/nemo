#!/usr/bin/env nim

import nimtalk/core/types
import nimtalk/parser/lexer

echo "Testing string tokenization..."
let tokens = lex("\"hello\"")
echo "Token count: ", tokens.len
for i, token in tokens:
  echo "  Token ", i, ": kind=", token.kind, " value='", token.value, "'"
