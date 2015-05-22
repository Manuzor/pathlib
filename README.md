pathlib
=======

Inspired by the python library `pathlib`.

## Differences to the python library API

_+ Addition | - Removal | $ Change_

* - There are no `PureXPath` base classes.
* - No `PureXPath` base classes.
* - No inheritance tree.
* $ Most operations/functions are D module functions but can be called as if they were members (thanks to D's unified function call syntax UFCS).
* $ `as_posix()` => `posixData()`.
* + `asPosix()` to convert between different paths.
* + `asNormalized()` to normalize a path, without resolving it. This works for all types of paths, regardless of the current system.
* `as_posix()` => `posixData()`. Additionally, there is also `windowsData()`.
* Instead of overloading operator `/`, the concatenation operator `~` is overloaded instead: `Path("hello") ~ "world" ~ "goodBye` // WindowsPath("hello\\world\\goodBye") or PosixPath("hello/world/goodBye")
* Instead of `suffix()` and `suffixes()` there are `extension()`, `extensions()`, and `fullExtension()`.
