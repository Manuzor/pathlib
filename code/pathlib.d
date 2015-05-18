/++
  Authors:
    Manuzor

  ToDo:
    - Path().open(...)
    - Path().glob(); Path().rglob();
+/
module pathlib;

static import std.path;
static import std.file;
import std.array      : array, replace, replaceLast, join;
import std.format     : format;
import std.string     : split, indexOf, empty, squeeze, stripRight, removechars;
import std.conv       : to;
import std.typecons   : Flag;
import std.traits     : isSomeString, isSomeChar;
import std.algorithm  : equal, map, reduce, endsWith, stripRight, remove;
import std.range      : iota, retro, take, isInputRange, repeat;
import std.functional : binaryFun;


debug
{
  void logDebug(T...)(T args) {
    import std.stdio;

    writefln(args);
  }
}

template assertEqual(alias predicate = "a == b")
{
  void assertEqual(A, B)(A a, B b) {
    static if (isInputRange!A && isInputRange!B) {
      assert(std.algorithm.equal!predicate(a, b), format("`%s` must be equal to `%s`", a, b));
    }
    else {
      assert(a == b, format("`%s` must be equal to `%s`", a, b));
    }
  }
}

void assertEmpty(A)(A a) {
  assert(a.empty, format("String `%s` should be empty.", a));
}


/// Whether $(D str) can be represented by ".".
bool isDot(StringType)(StringType str)
  if (isSomeString!StringType)
{
  auto data = str.removechars("./\\");
  return data.empty;
}

///
unittest {
  assert("".isDot);
  assert(".".isDot);
  assert("./".isDot);
  assert("./.".isDot);
  assert("././".isDot);
}


/// Whether the path is either "" or ".".
bool isDot(PathType)(PathType p)
  if (!isSomeString!PathType)
{
  return p.data.isDot;
}

///
unittest {
  assert(WindowsPath().isDot);
  assert(WindowsPath("").isDot);
  assert(WindowsPath(".").isDot);
  assert(PosixPath().isDot);
  assert(PosixPath("").isDot);
  assert(PosixPath(".").isDot);
}


/// Returns: The root of the path $(D p).
auto root(PathType)(PathType p) {
  auto data = p.data;

  static if(is(PathType == WindowsPath))
  {
    if (data.length > 1 && data[1] == ':') {
      return data[0..2];
    }
  }
  else // Assume PosixPath
  {
    if (data.length > 0 && data[0] == '/') {
      return data[0..1];
    }
  }

  return "";
}

///
unittest {
  assert(WindowsPath("").root == "");
  assert(PosixPath("").root == "");
  assert(WindowsPath("C:/Hello/World").root == "C:", WindowsPath("C:/Hello/World").root);
  assert(WindowsPath("/Hello/World").root == "");
  assert(PosixPath("/hello/world").root == "/", PosixPath("/hello/world").root);
  assert(PosixPath("C:/hello/world").root == "");
}


/// The drive of the path $(D p).
/// Note: Non-Windows platforms have no concept of "drives".
auto drive(PathType)(PathType p) {
  static if(is(PathType == WindowsPath))
  {
    auto data = p.data;
    if (data.length > 1 && data[1] == ':') {
      return data[0..2];
    }
  }

  return "";
}

///
unittest {
  assert(WindowsPath("").drive == "");
  assert(WindowsPath("/Hello/World").drive == "");
  assert(WindowsPath("C:/Hello/World").drive == "C:");
  assert(PosixPath("").drive == "");
  assert(PosixPath("/Hello/World").drive == "");
  assert(PosixPath("C:/Hello/World").drive == "", PosixPath("C:/Hello/World").drive);
}


/// Returns: The path data using forward slashes, regardless of the current platform.
auto posixData(PathType)(PathType p) {
  if (p.isDot) {
    return ".";
  }
  auto root = p.root;
  auto result = p.data[root.length..$].replace("\\", "/").squeeze("/");
  if (result.length > 1 && result[$ - 1] == '/') {
    result = result[0..$ - 1];
  }
  return root ~ result;
}

///
unittest {
  assertEqual(Path().posixData, ".");
  assertEqual(Path("").posixData, ".");
  assertEqual(Path("/hello/world").posixData, "/hello/world");
  assertEqual(Path("/\\hello/\\/////world//").posixData, "/hello/world");
  assertEqual(Path(`C:\`).posixData, "C:/");
  assertEqual(Path(`C:\hello\`).posixData, "C:/hello");
  assertEqual(Path(`C:\/\hello\`).posixData, "C:/hello");
  assertEqual(Path(`C:\some windows\/path.exe.doodee`).posixData, "C:/some windows/path.exe.doodee");
  assertEqual(Path(`C:\some windows\/path.exe.doodee\\\`).posixData, "C:/some windows/path.exe.doodee");
  assertEqual(Path(`C:\some windows\/path.exe.doodee\\\`).posixData, Path(Path(`C:\some windows\/path.exe.doodee\\\`).posixData).data);
  assertEqual((Path(".") ~ "hello" ~ "./" ~ "world").posixData, "hello/world");
}


/// Returns: The path data using backward slashes, regardless of the current platform.
auto windowsData(PathType)(PathType p) {
  return p.posixData.replace("/", "\\");
}

///
unittest {
  assertEqual(Path().windowsData, ".");
  assertEqual(Path("").windowsData, Path("").windowsData);
  assertEqual(Path("/hello/world").windowsData, `\hello\world`);
  assertEqual(Path("/\\hello/\\/////world//").windowsData, `\hello\world`);
  assertEqual(Path(`C:\`).windowsData, `C:\`);
  assertEqual(Path(`C:/`).windowsData, `C:\`);
  assertEqual(Path(`C:\hello\`).windowsData, `C:\hello`);
  assertEqual(Path(`C:\/\hello\`).windowsData, `C:\hello`);
  assertEqual(Path(`C:\some windows\/path.exe.doodee`).windowsData, `C:\some windows\path.exe.doodee`);
  assertEqual(Path(`C:\some windows\/path.exe.doodee\\\`).windowsData, `C:\some windows\path.exe.doodee`);
  assertEqual(Path(`C:/some windows\/path.exe.doodee\\\`).windowsData, Path(Path(`C:\some windows\/path.exe.doodee\\\`).windowsData).data);
}


/// Whether the path exists or not. It does not matter whether it is a file or not.
auto exists(PathType)(PathType p) {
  return std.file.exists(p.data);
}

///
unittest {
}


/// Whether the path is an existing directory.
auto isDir(PathType)(PathType p) {
  return p.exists && std.file.isDir(p.data);
}

///
unittest {
}


/// Whether the path is an existing file.
auto isFile(PathType)(PathType p) {
  return p.exists && std.file.isFile(p.data);
}

///
unittest {
}


/// Whether the path is absolute.
bool isAbsolute(PathType)(PathType p) {
  // If the path has a root or a drive, it is absolute.
  return !p.root.empty || !p.drive.empty;
}


// Resolve all ".", "..", and symlinks.
Path resolve(PathType)(PathType p) {
  return Path(std.path.absolutePath(p.data));
}

///
unittest {
}


/// Returns: The parts of the path as an array.
auto parts(PathType)(PathType p) {
  return std.path.pathSplitter(p.posixData).array;
}

///
unittest {
  import std.algorithm : equal;

  assert(Path().parts.equal(["."]));
  assert(Path("C:/hello/world.exe.xml").parts.equal(["C:/", "hello", "world.exe.xml"]));
  assert(Path("/hello/world.exe.xml").parts.equal(["/", "hello", "world.exe.xml"]));
}


/// Returns: The parts of the path as an array, without the last component.
auto parents(PathType)(PathType p) {
  auto theParts = p.parts.map!(x => PathType(x));
  return iota(theParts.length - 1, 0, -1).map!(x => theParts.take(x).reduce!((a, b){ return a ~ b; })).array;
}

///
unittest {
  assertEmpty(Path().parents);
  //assertEqual(WindowsPath("C:/hello/world").parents, [WindowsPath("C:/hello"), WindowsPath("C:/")]);
  //assertEqual(WindowsPath("C:/hello/world/").parents, [WindowsPath("C:/hello"), WindowsPath("C:/")]);
  //assertEqual(PosixPath("/hello/world").parents, [PosixPath("/hello"), PosixPath("/")]);
  //assertEqual(PosixPath("/hello/world/").parents, [PosixPath("/hello"), PosixPath("/")]);
}
// +/


mixin template PathCommon(PathType, StringType, alias defaultSep)
  if (isSomeString!StringType && isSomeChar!(typeof(defaultSep)))
{
  StringType data;

  ///
  unittest {
    assert(PathType().data != "");
    assert(PathType("123").data == "123");
    assert(PathType("C:///toomany//slashes!\\").data == "C:///toomany//slashes!\\");
  }


  /// Construct a path from the given string $(D str).
  static PathType opCall(InStringType)(InStringType str) if (isSomeString!InStringType) {
    PathType p;
    p.data = cast(StringType)str;
    return p;
  }

  ///
  unittest {
    static assert(__traits(compiles, PathType("/hello/world")));
  }


  /// Default construct a path, pointing to the current working directory (absolute path).
  static PathType opCall() {
    return PathType(".");
  }

  ///
  unittest {
    assert(PathType().data == ".");
  }


  void opOpAssign(string op)(PathType other)
    if (op == "~")
  {
    if (PathType(other.data).isDot) {
      return;
    }
    auto data = std.algorithm.stripRight(this.data, defaultSep);
    if (this.isDot) {
      data = other.data;
    }
    else {
      data = format("%s%c%s", data, defaultSep, other.data);
    }

    this.data = data;
  }

  ///
  unittest {
    {
      auto p = PathType();
      p ~= "hello";
      assertEqual(p, PathType("hello"));
    }
    {
      auto p = PathType("");
      p ~= "hello";
      assertEqual(p, PathType("hello"));
    }
    {
      auto p = PathType(".");
      p ~= "hello";
      assertEqual(p, PathType("hello"));
    }
  }


  /// Concatenate the path-string $(D str) to this path.
  void opOpAssign(string op, InStringType)(InStringType str)
    if (op == "~" && isSomeString!InStringType)
  {
    this ~= PathType(str);
  }

  ///
  unittest {
    PathType p;
    p ~= "hello";
    assert(p == PathType("hello"));
  }


  /// Concatenate two paths.
  auto opBinary(string op)(PathType other) const
    if (op == "~")
  {
    auto p = PathType(data);
    p ~= other;
    return p;
  }

  ///
  unittest {
    assertEqual((PathType("C:/hello") ~ PathType("world.exe.xml")), PathType("C:/hello" ~ defaultSep ~ "world.exe.xml"));
    assertEqual(PathType() ~ "hello", PathType("hello"));
    assertEqual(PathType("") ~ "hello", PathType("hello"));
    assertEqual(PathType(".") ~ "hello", PathType("hello"));
  }


  /// Concatenate a path and a string, which will be treated as a path.
  auto opBinary(string op, InStringType)(InStringType str) const
    if (op == "~" && isSomeString!InStringType)
  {
    return this ~ PathType(str);
  }

  ///
  unittest {
    assertEqual(PathType() ~ "hello", PathType("hello"));
    assertEqual(PathType("") ~ "hello", PathType("hello"));
    assertEqual(PathType(".") ~ "hello", PathType("hello"));
  }


  /// Equality overload.
  bool opBinary(string op)(auto ref const PathType other) const
    if (op == "==")
  {
    auto l = this.data.empty ? "." : this.data;
    auto r = other.data.empty ? "." : other.data;
    return l == r;
  }

  ///
  unittest {
    auto p1 = PathType("/hello/world");
    auto p2 = PathType("/hello/world");
    assertEqual(p1, p2);
  }


  /// Cast the path to a string.
  auto toString(OtherStringType = StringType)() const {
    return this.data.to!OtherStringType;
  }

  ///
  unittest {
    assertEqual(PathType("C:/hello/world.exe.xml").to!StringType, "C:/hello/world.exe.xml");
  }
}


struct WindowsPath
{
  mixin PathCommon!(WindowsPath, string, '\\');
}


struct PosixPath
{
  mixin PathCommon!(PosixPath, string, '/');
}

/// Set the default path depending on the current platform.
version(Windows)
{
  alias Path = WindowsPath;
}
else // Assume posix on non-windows platforms.
{
  alias Path = PosixPath;
}
