# 1.1.0
* Upgrade for Dart 2.
* Allow structs to have names.
* `Field.value` is now optional.

# 1.0.0+5
* Fixed a bug that caused `Field`s to generate incorrect code.
* Added `suffix`, `asFloat`, `asDouble`, and `asByte` to `Expression`.
* `Expression.asThrow` now returns an `Expression`.
* Added `CType.auto`.

# 1.0.0+4
* Added `pointerType` to `FunctionSignature`.

# 1.0.0+3
* Add `size_t`, `ptrdiff_t`.
* Add `invoke` to `Expression`.

# 1.0.0+2
* Allow the creation of `Enum`s.
* Add `extern`, `inline`, and `enum$` prefixes to `CType`.
* Added to `_escapeQuotes`.

# 1.0.0+1
* Fixed a tiny bug where integers would be printed with quotes.

# 1.0.0
Initial version.