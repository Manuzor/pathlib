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
static import std.uni;
import std.array      : array, replace, replaceLast, join;
import std.format     : format;
import std.string     : split, indexOf, empty, squeeze, removechars, lastIndexOf;
import std.conv       : to;
import std.typecons   : Flag;
import std.traits     : isSomeString, isSomeChar;
import std.algorithm  : equal, map, reduce, startsWith, endsWith, strip, stripRight, stripLeft, remove;
import std.range      : iota, take, isInputRange;


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
  if (str.length && str[0] != '.') {
    return false;
  }
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
  assert(!"/".isDot);
  assert(!"hello".isDot);
  assert(!".git".isDot);
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
  return p.posixData.replace("/", `\`);
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


/// Will call either posixData or windowsData, according to PathType.
auto normalizedData(PathType)(PathType p)
  if(is(PathType == PosixPath) || is(PathType == WindowsPath))
{
  static if (is(PathType == PosixPath)) {
    return p.posixData;
  }
  else static if (is(PathType == WindowsPath)) {
    return p.windowsData;
  }
}


/// Whether the path is absolute.
bool isAbsolute(PathType)(PathType p) {
  // If the path has a root or a drive, it is absolute.
  return !p.root.empty || !p.drive.empty;
}


/// Returns: The parts of the path as an array.
auto parts(PathType)(PathType p) {
  string[] theParts;
  auto root = p.root;
  if (!root.empty) {
    static if(is(PathType == WindowsPath)) {
      root ~= p.separator;
    }
    theParts ~= root;
  }
  theParts ~= p.posixData[root.length .. $].strip('/').split('/')[];
  return theParts;
}

///
unittest {
  assertEqual(Path().parts, ["."]);
  assertEqual(Path("./.").parts, ["."]);
  assertEqual(WindowsPath("hello/world.exe.xml").parts, ["hello", "world.exe.xml"]);
  assertEqual(WindowsPath("C:/hello/world.exe.xml").parts, [`C:\`, "hello", "world.exe.xml"]);
  assertEqual(PosixPath("hello/world.exe.xml").parts, ["hello", "world.exe.xml"]);
  assertEqual(PosixPath("/hello/world.exe.xml").parts, ["/", "hello", "world.exe.xml"]);
}


/// Returns: The parts of the path as an array, without the last component.
auto parents(PathType)(PathType p) {
  auto theParts = p.parts.map!(x => PathType(x));
  return iota(theParts.length - 1, 0, -1).map!(x => theParts.take(x).reduce!((a, b){ return a ~ b; })).array;
}

///
unittest {
  assertEmpty(Path().parents);
  assertEqual(WindowsPath("C:/hello/world").parents, [WindowsPath(`C:\hello`), WindowsPath(`C:\`)]);
  assertEqual(WindowsPath("C:/hello/world/").parents, [WindowsPath(`C:\hello`), WindowsPath(`C:\`)]);
  assertEqual(PosixPath("/hello/world").parents, [PosixPath("/hello"), PosixPath("/")]);
  assertEqual(PosixPath("/hello/world/").parents, [PosixPath("/hello"), PosixPath("/")]);
}


/// The name of the path without any of its parents.
auto name(PathType)(PathType p) {
  import std.algorithm : min;

  auto data = p.posixData;
  auto i = min(data.lastIndexOf('/') + 1, data.length);
  return data[i .. $];
}

///
unittest {
  assertEqual(Path().name, ".");
  assertEqual(Path("").name, ".");
  assertEmpty(Path("/").name);
  assertEqual(Path("/hello").name, "hello");
  assertEqual(Path("C:\\hello").name, "hello");
  assertEqual(Path("C:/hello/world.exe").name, "world.exe");
  assertEqual(Path("hello/world.foo.bar.exe").name, "world.foo.bar.exe");
}


/// The extension of the path including the leading dot.
///
/// Examples: The extension of "hello.foo.bar.exe" is "exe".
auto extension(PathType)(PathType p) {
  auto data = p.name;
  auto i = data.lastIndexOf('.');
  if (i < 0) {
    return "";
  }
  if (i + 1 == data.length) {
    // This prevents preserving the dot in empty extensions such as `hello.foo.`.
    ++i;
  }
  return data[i .. $];
}

///
unittest {
  assertEmpty(Path().extension);
  assertEmpty(Path("").extension);
  assertEmpty(Path("/").extension);
  assertEmpty(Path("/hello").extension);
  assertEmpty(Path("C:/hello/world").extension);
  assertEqual(Path("C:/hello/world.exe").extension, ".exe");
  assertEqual(Path("hello/world.foo.bar.exe").extension, ".exe");
}


/// All extensions of the path.
auto extensions(PathType)(PathType p) {
  import std.algorithm : splitter, filter;
  import std.range : dropOne;

  auto result = p.name.splitter('.').filter!(a => !a.empty);
  if (!result.empty) {
    result = result.dropOne;
  }
  return result.map!(a => '.' ~ a).array;
}

///
unittest {
  assertEmpty(Path().extensions);
  assertEmpty(Path("").extensions);
  assertEmpty(Path("/").extensions);
  assertEmpty(Path("/hello").extensions);
  assertEmpty(Path("C:/hello/world").extensions);
  assertEqual(Path("C:/hello/world.exe").extensions, [".exe"]);
  assertEqual(Path("hello/world.foo.bar.exe").extensions, [".foo", ".bar", ".exe"]);
}


/// The full extension of the path.
///
/// Examples: The full extension of "hello.foo.bar.exe" would be "foo.bar.exe".
auto fullExtension(PathType)(PathType p) {
  auto data = p.name;
  auto i = data.indexOf('.');
  if (i < 0) {
    return "";
  }
  if (i + 1 == data.length) {
    // This prevents preserving the dot in empty extensions such as `hello.foo.`.
    ++i;
  }
  return data[i .. $];
}

///
unittest {
  assertEmpty(Path().fullExtension);
  assertEmpty(Path("").fullExtension);
  assertEmpty(Path("/").fullExtension);
  assertEmpty(Path("/hello").fullExtension);
  assertEmpty(Path("C:/hello/world").fullExtension);
  assertEqual(Path("C:/hello/world.exe").fullExtension, ".exe");
  assertEqual(Path("hello/world.foo.bar.exe").fullExtension, ".foo.bar.exe");
}


/// Whether the path exists or not. It does not matter whether it is a file or not.
auto exists(Path p) {
  return std.file.exists(p.data);
}

///
unittest {
}


/// Whether the path is an existing directory.
auto isDir(Path p) {
  return p.exists && std.file.isDir(p.data);
}

///
unittest {
}


/// Whether the path is an existing file.
auto isFile(Path p) {
  return p.exists && std.file.isFile(p.data);
}

///
unittest {
}


// Resolve all ".", "..", and symlinks.
Path resolve(Path p) {
  return Path(std.path.absolutePath(p.data));
}

///
unittest {
}


mixin template PathCommon(PathType, StringType, alias defaultSep, alias cmpFunc)
  if (isSomeString!StringType && isSomeChar!(typeof(defaultSep)))
{
  StringType data = ".";

  ///
  unittest {
    assert(PathType().data != "");
    assert(PathType("123").data == "123");
    assert(PathType("C:///toomany//slashes!\\").data == "C:///toomany//slashes!\\");
  }


  @property auto separator() const { return defaultSep; }


  /// Concatenate a path and a string, which will be treated as a path.
  auto opBinary(string op, InStringType)(InStringType str) const
    if (op == "~" && isSomeString!InStringType)
  {
    return this ~ PathType(str);
  }

  /// Concatenate two paths.
  auto opBinary(string op)(PathType other) const
    if (op == "~")
  {
    auto p = PathType(data);
    p ~= other;
    return p;
  }

  /// Concatenate the path-string $(D str) to this path.
  void opOpAssign(string op, InStringType)(InStringType str)
    if (op == "~" && isSomeString!InStringType)
  {
    this ~= PathType(str);
  }

  /// Concatenate the path $(D other) to this path.
  void opOpAssign(string op)(PathType other)
    if (op == "~")
  {
    auto l = PathType(this.normalizedData);
    auto r = PathType(other.normalizedData);

    if (l.isDot || r.isAbsolute) {
      this.data = r.data;
      return;
    }

    if (r.isDot) {
      this.data = l.data;
      return;
    }

    auto sep = "";
    if (!l.data.endsWith('/', '\\') && !r.data.startsWith('/', '\\')) {
      sep = [defaultSep];
    }

    this.data = format("%s%s%s", l.data, sep, r.data);
  }

  ///
  unittest {
    assertEqual(PathType() ~ "hello", PathType("hello"));
    assertEqual(PathType("") ~ "hello", PathType("hello"));
    assertEqual(PathType(".") ~ "hello", PathType("hello"));
    assertEqual(PosixPath("/") ~ "hello", PosixPath("/hello"));
    assertEqual(WindowsPath("/") ~ "hello", WindowsPath(`\hello`));
    assertEqual(PosixPath("/") ~ "hello" ~ "world", PosixPath("/hello/world"));
    assertEqual(WindowsPath(`C:\`) ~ "hello" ~ "world", WindowsPath(`C:\hello\world`));
  }


  /// Equality overload.
  bool opBinary(string op)(auto ref const PathType other) const
    if (op == "==")
  {
    auto l = this.data.empty ? "." : this.data;
    auto r = other.data.empty ? "." : other.data;
    return cmpFunc(l, r);
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
  mixin PathCommon!(WindowsPath, string, '\\', std.uni.sicmp);
}


struct PosixPath
{
  mixin PathCommon!(PosixPath, string, '/', std.algorithm.cmp);
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
