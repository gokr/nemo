# VSCode Extension for Harding

## Overview

The Harding repository includes a VSCode extension that provides syntax highlighting for `.harding` files. This allows developers to get immediate syntax highlighting without needing to install a separate extension from the marketplace.

## Installation

### From the Repository

The extension file is included in the repository as `harding-lang-0.1.0.vsix`.

**Command line:**
```bash
code --install-extension harding-lang-0.1.0.vsix
```

**From VSCode:**
1. Press `Ctrl+Shift+P` (Cmd+Shift+P on Mac)
2. Type "Extensions: Install from VSIX..."
3. Select `harding-lang-0.1.0.vsix`
4. Reload VSCode when prompted

### Rebuilding the Extension

If you modify the grammar or language configuration, rebuild the extension:

```bash
npm install -g @vscode/vsce
vsce package
```

The resulting `.vsix` file can be installed as described above.

## Syntax Highlighting

The grammar provides scopes for the following constructs:

| Construct | Scope | Example |
|-----------|-------|---------|
| Comments | `comment.line.harding` | `# This is a comment` |
| Strings | `string.quoted.double.harding` | `"hello"` |
| Symbols | `entity.name.tag.symbol.harding` | `#foo`, `#bar:baz:` |
| Symbols (quoted) | `entity.name.tag.symbol.quoted.harding` | `"symbol with spaces"` |
| Numbers | `constant.numeric.harding` | `42`, `3.14`, `-10` |
| Booleans | `constant.language.harding` | `true`, `false` |
| Nil | `constant.language.harding` | `nil` |
| Self/Super | `constant.language.harding` | `self`, `super` |
| Globals (classes) | `constant.other.class.harding` | `Object`, `Point` |
| Variables | `variable.other.harding` | `x`, `message` |
| Block parameters | `variable.parameter.harding` | `:param`, `:x :y` |
| Block temps | `variable.other.temporary.harding` | `| temp1 temp2` |
| Keywords | `keyword.control.harding` | `ifTrue:`, `at:put:` |
| Assignment | `keyword.operator.assignment.harding` | `:=` |
| Return | `keyword.operator.return.harding` | `^` |
| Method def | `keyword.operator.method-definition.harding` | `>>` |
| Arrow | `keyword.operator.arrow.harding` | `->` |
| Operators | `keyword.operator.harding` | `+`, `-`, `*`, `/`, `&`, `\|` |
| Arrays | `meta.array.literal.harding` | `#(1 2 3)` |
| Tables | `meta.table.literal.harding` | `#{"key" -> "value"}` |
| Objects | `meta.object.literal.harding` | `{| x: 1 \|}` |
| Primitives | `support.function.primitive.harding` | `<primitive>...</primitive>` |

## Files

| File | Purpose |
|------|---------|
| `.vscode/syntaxes/harding.tmLanguage.json` | TextMate grammar definition |
| `.vscode/language-configuration.json` | Bracket matching, word patterns |
| `.vscode/settings.json` | File association for `.harding` files |
| `package.json` | Extension manifest |
| `.vscodeignore` | Files to exclude from `.vsix` |
| `harding-lang-0.1.0.vsix` | Packaged extension |

## Verifying Syntax Highlighting

To check that syntax highlighting is working correctly:

1. Open any `.harding` file in VSCode
2. Press `Ctrl+Shift+P` (Cmd+Shift+P on Mac)
3. Type "Developer: Inspect Editor Tokens and Scopes"
4. Move your cursor over different code elements
5. A popup will show the scopes applied (e.g., `source.harding keyword.control.harding`)

## Customizing Colors

To customize the colors in your VSCode settings (`settings.json`):

```json
{
  "editor.tokenColorCustomizations": {
    "textMateRules": [
      {
        "scope": "entity.name.tag.symbol.harding",
        "settings": {
          "foreground": "#ff5555"
        }
      },
      {
        "scope": "constant.other.class.harding",
        "settings": {
          "foreground": "#8be9fd",
          "fontStyle": "bold"
        }
      }
    ]
  }
}
```

## Grammar Notes

### Comment vs Symbol Disambiguation

The grammar distinguishes between comments (`# comment`) and symbols (`#foo`):
- Comments require a space after the `#` or special characters
- Symbols require a letter/underscore immediately after `#`

This prevents cases like `#primitiveIsKindOf:` from being incorrectly highlighted as comments.

### Identifiers vs Globals

- Identifiers starting with lowercase: `variable.other.harding`
- Identifiers starting with uppercase: `constant.other.class.harding`

This convention makes class references stand out from local variables.

## Troubleshooting

**Extension not loading:**
- Ensure VSCode is reloaded after installation
- Check that the `.harding` file extension is associated with Harding (should happen automatically)

**Incorrect highlighting:**
- Use "Developer: Inspect Editor Tokens and Scopes" to verify which scopes are applied
- If needed, rebuild and reinstall the extension after modifying the grammar

**Extension file too large:**
- Check `.vscodeignore` to ensure source files are excluded
- Run `vsce package` again after updating `.vscodeignore`
