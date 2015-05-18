pathlib
=======

Inspired by the python library `pathlib`.

## Differences to the python library API

* There are no `PureXPath` base classes.
* `as_posix` => `posixData`. Additionally, there is also `windowsData`.
* Instead of overloading operator `/`, the concatenation operator `~` is overloaded instead: `Path("hello") ~ "world" ~ "goodBye` // WindowsPath("hello\\world\\goodBye") or PosixPath("hello/world/goodBye")
