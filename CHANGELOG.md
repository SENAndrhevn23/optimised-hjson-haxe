# Note:
Versions under 1.0.3 should not be used.

## [1.0.4] - 2026-08-02
### Fixes
- **Anonymous Objects Compatibility**: `HJSONParser` now returns native Haxe anonymous objects (`{}`) instead of `Map`, ensuring full compatibility with `Reflect` and `HJSONWriter`.
- **Unquoted Strings with Spaces**: Improved `readIdentifier()` in `Tokenizer` to correctly capture multi-word strings without quotes up to newlines.
- **Escaping**: Proper handling of escape characters (`\n`, `\t`, `\"`, `\\`) during string parsing.
- **Cross-Platform Compilation**: Wrapped file I/O operations (`parseFile`, `saveToFile`) inside `#if sys` guards to allow compilation on JS/Web targets.

### Changes
- **Comment Support**: Full support for line comments (`//`, `#`) and block comments (`/* */`) in the Tokenizer.
- **Compile-Time Macros**: Added `hjson.macro.HJSONMacro.parseFile()` for embedding HJSON assets directly during compilation.
- **Flexible Options**: Introduced `ParseOptions` and `WriteOptions` (`indentSize`, `quoteKeys`, `useCommas`, `pretty`).
- **Refactored Core**: Removed external `HStringTools` in favor of native Haxe `StringTools` and `StringBuf`.
- **New Directory Structure**: Restructured package directory under `hjson.*` (`hjson.core`, `hjson.macro`, `hjson.tokenizer`).


## [1.0.3] – 2025-09-15
### Changes
- Modularized `Token` and `TokenType` into separate files.
- Added support for optional quotes and commas in HJSON syntax.
- Added file input/output support (`parseFile` and `saveToFile`).
- Refactored HJSON parser and writer for better maintainability.

## Minimal Change (2026/08/02)
- Added `Update.hx`

## [1.0.2] – 2025-08-30
### Changes
- Deprecated the library; this library should not be used.

## [1.0.1] – 2025-08-20
### Changes
- Fixing URL in `haxelib.json`

## [1.0.0] – 2025-08-15
### Initial Release
- Core HJSON parsing and writing functionality.
- Handles objects, arrays, numbers, strings, booleans, and nulls.
- Supports optional commas (configurable).
