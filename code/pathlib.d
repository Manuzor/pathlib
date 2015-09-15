/++
  Authors:
    Manuzor

  ToDo:
    - Path().open(...)
+/
module pathlib;

public import std.file : SpanMode;

static import std.path;
static import std.file;
static import std.uni;
import std.algorithm;
import std.array      : array, replace, replaceLast;
import std.format     : format;
import std.string     : split, indexOf, empty, squeeze, removechars, lastIndexOf;
import std.conv       : to;
import std.typecons   : Flag;
import std.traits     : isSomeString, isSomeChar;
import std.range      : iota, take, isInputRange;
import std.typetuple;

debug
{
  void logDebug(T...)(T args) {
    import std.stdio;

    writefln(args);
  }
}

void assertEqual(alias predicate = "a == b", A, B, StringType = string)
                (A a, B b, StringType fmt = "`%s` must be equal to `%s`")
{
  static if(isInputRange!A && isInputRange!B) {
    assert(std.algorithm.equal!predicate(a, b), format(fmt, a, b));
  }
  else {
    import std.functional : binaryFun;
    assert(binaryFun!predicate(a, b), format(fmt, a, b));
  }
}

void assertNotEqual(alias predicate = "a != b", A, B, StringType = string)
                    (A a, B b, StringType fmt = "`%s` must not be equal to `%s`")
{
  assertEqual!predicate(a, b, fmt);
}

void assertEmpty(A, StringType = string)(A a, StringType fmt = "String `%s` should be empty.") {
  assert(a.empty, format(fmt, a));
}

void assertNotEmpty(A, StringType = string)(A a, StringType fmt = "String `%s` should be empty.") {
  assert(!a.empty, format(fmt, a));
}

template isSomePath(PathType)
{
  enum isSomePath = is(PathType == WindowsPath) ||
                    is(PathType == PosixPath);
}

///
unittest
{
  static assert(isSomePath!WindowsPath);
  static assert(isSomePath!PosixPath);
  static assert(!isSomePath!string);
}


/// Exception that will be thrown when any path operations fail.
class PathException : Exception
{
  @safe pure nothrow
  this(string msg)
  {
    super(msg);
  }
}


mixin template PathCommon(TheStringType, alias theSeparator, alias theCaseSensitivity)
  if(isSomeString!TheStringType && isSomeString!(typeof(theSeparator)))
{
  alias PathType = typeof(this);
  alias StringType = TheStringType;

  StringType data = ".";

  ///
  unittest
  {
    assert(PathType().data != "");
    assert(PathType("123").data == "123");
    assert(PathType("C:///toomany//slashes!\\").data == "C:///toomany//slashes!\\");
  }


  /// Used to separate each path segment.
  alias separator = theSeparator;


  /// A value of std.path.CaseSensitive whether this type of path is case sensetive or not.
  alias caseSensitivity = theCaseSensitivity;


  /// Concatenate a path and a string, which will be treated as a path.
  auto opBinary(string op : "~", InStringType)(auto ref in InStringType str) const
    if(isSomeString!InStringType)
  {
    return this ~ PathType(str);
  }

  /// Concatenate two paths.
  auto opBinary(string op : "~")(auto ref in PathType other) const
    if(isSomePath!PathType)
  {
    auto p = PathType(this.data);
    p ~= other;
    return p;
  }

  /// Concatenate the path-string $(D str) to this path.
  void opOpAssign(string op : "~", InStringType)(auto ref in InStringType str)
    if(isSomeString!InStringType)
  {
    this ~= PathType(str);
  }

  /// Concatenate the path $(D other) to this path.
  void opOpAssign(string op : "~")(auto ref in PathType other)
    if(isSomePath!PathType)
  {
    auto l = PathType(this.normalizedData);
    auto r = PathType(other.normalizedData);

    //logDebug("~= %s: %s => %s | %s => %s", PathType.stringof, this.data, l, other.data, r);

    if(l.isDot || r.isAbsolute) {
      this.data = r.data;
      return;
    }

    if(r.isDot) {
      this.data = l.data;
      return;
    }

    auto sep = "";
    if(!l.data.endsWith('/', '\\') && !r.data.startsWith('/', '\\')) {
      sep = this.separator;
    }

    this.data = l.data ~ sep ~ r.data;
  }

  ///
  unittest
  {
    assertEqual(PathType() ~ "hello", PathType("hello"));
    assertEqual(PathType("") ~ "hello", PathType("hello"));
    assertEqual(PathType(".") ~ "hello", PathType("hello"));

    assertEqual(WindowsPath("/") ~ "hello", WindowsPath(`hello`));
    assertEqual(WindowsPath(`C:\`) ~ "hello" ~ "world", WindowsPath(`C:\hello\world`));
    assertEqual(WindowsPath("hello") ~ "..", WindowsPath(`hello\..`));
    assertEqual(WindowsPath("..") ~ "hello", WindowsPath(`..\hello`));

    assertEqual(PosixPath("/") ~ "hello", PosixPath("/hello"));
    assertEqual(PosixPath("/") ~ "hello" ~ "world", PosixPath("/hello/world"));
    assertEqual(PosixPath("hello") ~ "..", PosixPath("hello/.."));
    assertEqual(PosixPath("..") ~ "hello", PosixPath("../hello"));
  }

  /// Equality overload.
  bool opEquals()(auto ref in PathType other) const
  {
    static if(theCaseSensitivity == std.path.CaseSensitive.no) {
      return std.uni.sicmp(this.normalizedData, other.normalizedData) == 0;
    }
    else {
      return std.algorithm.cmp(this.normalizedData, other.normalizedData) == 0;
    }
  }

  int opCmp(ref const PathType other) const
  {
    static if(theCaseSensitivity == std.path.CaseSensitive.no) {
      return std.uni.sicmp(this.normalizedData, other.normalizedData);
    }
    else {
      return std.algorithm.cmp(this.normalizedData, other.normalizedData);
    }
  }

  ///
  unittest
  {
    assertEqual(PathType(""), PathType(""));
    assertEqual(PathType("."), PathType(""));
    assertEqual(PathType(""), PathType("."));
    auto p1 = PathType("/hello/world");
    auto p2 = PathType("/hello/world");
    assertEqual(p1, p2);
    static if(is(PathType == WindowsPath))
    {
      auto p3 = PathType("/hello/world");
    }
    else static if(is(PathType == PosixPath))
    {
      auto p3 = PathType("/hello\\world");
    }
    auto p4 = PathType("/hello\\world");
    assertEqual(p3, p4);
  }


  /// Cast the path to a string.
  auto toString(OtherStringType = StringType)() const {
    return this.data.to!OtherStringType;
  }

  ///
  unittest
  {
    assertEqual(PathType("C:/hello/world.exe.xml").to!StringType, "C:/hello/world.exe.xml");
  }
}


struct WindowsPath
{
  mixin PathCommon!(string, `\`, std.path.CaseSensitive.no);

  version(Windows)
  {
    /// Overload conversion `to` for Path => std.file.DirEntry.
    auto opCast(To : std.file.DirEntry)() const
    {
      return To(this.normalizedData);
    }

    ///
    unittest
    {
      auto d = cwd().to!(std.file.DirEntry);
    }
  }
}


struct PosixPath
{
  mixin PathCommon!(string, "/", std.path.CaseSensitive.yes);

  version(Posix)
  {
    /// Overload conversion `to` for Path => std.file.DirEntry.
    auto opCast(To : std.file.DirEntry)() const
    {
      return To(this.normalizedData);
    }

    ///
    unittest
    {
      auto d = cwd().to!(std.file.DirEntry);
    }
  }
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


/// Helper struct to change the directory for the current scope.
struct ScopedChdir
{
  Path prevDir;

  this(in Path newDir)
  {
    this.prevDir = cwd();
    if(newDir.isAbsolute) {
      chdir(newDir);
    }
    else {
      chdir(cwd() ~ newDir);
    }
  }

  /// Convenience overload that takes a string.
  this(string newDir) {
    this(Path(newDir));
  }

  ~this() {
    chdir(this.prevDir);
  }
}

///
unittest
{
  auto orig = cwd();
  with(ScopedChdir("..")) {
    assertNotEqual(orig, cwd());
  }
  assertEqual(orig, cwd());
}


/// Whether $(D str) can be represented by ".".
bool isDot(StringType)(auto ref in StringType str)
  if(isSomeString!StringType)
{
  if(str.length > 0 && str[0] != '.') {
    return false;
  }
  if(str.startsWith("..")) {
    return false;
  }
  auto data = str.removechars("./\\");
  return data.empty;
}

///
unittest
{
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
auto isDot(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  return p.data.isDot;
}

///
unittest
{
  assert(WindowsPath().isDot);
  assert(WindowsPath("").isDot);
  assert(WindowsPath(".").isDot);
  assert(!WindowsPath("/").isDot);
  assert(!WindowsPath("hello").isDot);
  assert(PosixPath().isDot);
  assert(PosixPath("").isDot);
  assert(PosixPath(".").isDot);
  assert(!PosixPath("/").isDot);
  assert(!PosixPath("hello").isDot);
}


/// Returns: The root of the path $(D p).
auto root(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  static if(is(PathType == WindowsPath))
  {
    return p.drive;
  }
  else // Assume PosixPath
  {
    auto data = p.data;
    if(data.length > 0 && data[0] == '/') {
      return data[0..1];
    }

    return "";
  }
}

///
unittest
{
  assertEqual(WindowsPath("").root, "");
  assertEqual(PosixPath("").root, "");
  assertEqual(WindowsPath("C:/Hello/World").root, "C:");
  assertEqual(WindowsPath("/Hello/World").root, "");
  assertEqual(PosixPath("/hello/world").root, "/");
  assertEqual(PosixPath("C:/hello/world").root, "");
}


/// The drive of the path $(D p).
/// Note: Non-Windows platforms have no concept of "drives".
auto drive(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  static if(is(PathType == WindowsPath))
  {
    auto data = p.data;
    if(data.length > 1 && data[1] == ':') {
      return data[0..2];
    }
  }

  return "";
}

///
unittest
{
  assertEqual(WindowsPath("").drive, "");
  assertEqual(WindowsPath("/Hello/World").drive, "");
  assertEqual(WindowsPath("C:/Hello/World").drive, "C:");
  assertEqual(PosixPath("").drive, "");
  assertEqual(PosixPath("/Hello/World").drive, "");
  assertEqual(PosixPath("C:/Hello/World").drive, "");
}


/// Returns: The path data using forward slashes, regardless of the current platform.
auto posixData(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  return normalizedDataImpl!"posix"(p);
}

///
unittest
{
  assertEqual(WindowsPath().posixData, ".");
  assertEqual(WindowsPath(``).posixData, ".");
  assertEqual(WindowsPath(`.`).posixData, ".");
  assertEqual(WindowsPath(`..`).posixData, "..");
  assertEqual(WindowsPath(`/foo/bar`).posixData, `foo/bar`);
  assertEqual(WindowsPath(`/foo/bar/`).posixData, `foo/bar`);
  assertEqual(WindowsPath(`C:\foo/bar.exe`).posixData, `C:/foo/bar.exe`);
  assertEqual(WindowsPath(`./foo\/../\/bar/.//\/baz.exe`).posixData, `foo/../bar/baz.exe`);

  assertEqual(PosixPath().posixData, `.`);
  assertEqual(PosixPath(``).posixData, `.`);
  assertEqual(PosixPath(`.`).posixData, `.`);
  assertEqual(PosixPath(`..`).posixData, `..`);
  assertEqual(PosixPath(`/foo/bar`).posixData, `/foo/bar`);
  assertEqual(PosixPath(`/foo/bar/`).posixData, `/foo/bar`);
  assertEqual(PosixPath(`.//foo\ bar/.//./baz.txt`).posixData, `foo\ bar/baz.txt`);
}


/// Returns: The path data using backward slashes, regardless of the current platform.
auto windowsData(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  return normalizedDataImpl!"windows"(p);
}

///
unittest
{
  assertEqual(WindowsPath().windowsData, `.`);
  assertEqual(WindowsPath(``).windowsData, `.`);
  assertEqual(WindowsPath(`.`).windowsData, `.`);
  assertEqual(WindowsPath(`..`).windowsData, `..`);
  assertEqual(WindowsPath(`C:\foo\bar.exe`).windowsData, `C:\foo\bar.exe`);
  assertEqual(WindowsPath(`C:\foo\bar\`).windowsData, `C:\foo\bar`);
  assertEqual(WindowsPath(`C:\./foo\.\\.\\\bar\`).windowsData, `C:\foo\bar`);
  assertEqual(WindowsPath(`C:\./foo\..\\.\\\bar\//baz.exe`).windowsData, `C:\foo\..\bar\baz.exe`);

  assertEqual(PosixPath().windowsData, `.`);
  assertEqual(PosixPath(``).windowsData, `.`);
  assertEqual(PosixPath(`.`).windowsData, `.`);
  assertEqual(PosixPath(`..`).windowsData, `..`);
  assertEqual(PosixPath(`/foo/bar.txt`).windowsData, `foo\bar.txt`);
  assertEqual(PosixPath(`/foo/bar\`).windowsData, `foo\bar`);
  assertEqual(PosixPath(`/foo/bar\`).windowsData, `foo\bar`);
  assertEqual(PosixPath(`/./\\foo/\/.\..\bar/./baz.txt`).windowsData, `foo\..\bar\baz.txt`);
}


/// Remove duplicate directory separators and stand-alone dots, on a textual basis.
/// Does not resolve ".."s in paths, since this would be wrong when dealing with symlinks.
/// Given the symlink "/foo" pointing to "/what/ever", the path "/foo/../baz.exe" would 'physically' be "/what/baz.exe".
/// If "/foo" was no symlink, the actual path would be "/baz.exe".
///
/// If you need to resolve ".."s and symlinks, see resolved().
auto normalizedData(PathType)(auto ref in PathType p)
  if(allSatisfy!(isSomePath, PathType))
{
  static if(is(PathType == WindowsPath))
  {
    return p.windowsData;
  }
  else static if(is(PathType == PosixPath))
  {
    return p.posixData;
  }
}

private auto normalizedDataImpl(alias target, PathType)(in PathType p)
{
  static assert(target == "posix" || target == "windows");

  if(p.isDot) {
    return ".";
  }

  static if(target == "windows")
  {
    auto sep = WindowsPath.separator;
  }
  else static if(target == "posix")
  {
    auto sep = PosixPath.separator;
  }

  // Note: We cannot make use of std.path.buildNormalizedPath because it textually resolves ".."s in paths.
  static if(is(PathType == WindowsPath))
  {
    //logDebug("WindowsPath 1: %s", p.data);
    //logDebug("WindowsPath 2: %s", p.data.replace(WindowsPath.separator, PosixPath.separator));
    //logDebug("WindowsPath 3: %s", p.data.replace(WindowsPath.separator, PosixPath.separator)
    //                                    .split(PosixPath.separator));
    //logDebug("WindowsPath 4: %s", p.data.replace(WindowsPath.separator, PosixPath.separator)
    //                                    .split(PosixPath.separator)
    //                                    .filter!(a => !a.empty && !a.isDot));
    //logDebug("WindowsPath 5: %s", p.data.replace(WindowsPath.separator, PosixPath.separator)
    //                                    .split(PosixPath.separator)
    //                                    .filter!(a => !a.empty && !a.isDot)
    //                                    .joiner(sep));

    // For WindowsPaths, replace "\" with "/".
    return p.data.replace(WindowsPath.separator, PosixPath.separator)
                 .split(PosixPath.separator)
                 .filter!(a => !a.empty && !a.isDot)
                 .joiner(sep)
                 .to!string();
  }
  else static if(is(PathType == PosixPath))
  {
    // For PosixPaths, do not replace any "\"s and make sure to append the root as prefix,
    // since it would get `split` away.

    static if(target == "windows")
    {
      return WindowsPath(p.data).windowsData;
    }
    else static if(target == "posix")
    {
      auto root = p.root;

      //logDebug("PosixPath root: %s", root);
      //logDebug("PosixPath 1: %s", root ~ p.data);
      //logDebug("PosixPath 2: %s", root ~ p.data.split(PosixPath.separator));
      //logDebug("PosixPath 3: %s", root ~ p.data.split(PosixPath.separator)
      //                                           .filter!(a => !a.empty && !a.isDot)
      //                                           .to!string);
      //logDebug("PosixPath 4: %s", root ~ p.data.split(PosixPath.separator)
      //                                           .filter!(a => !a.empty && !a.isDot)
      //                                           .joiner(sep)
      //                                           .to!string);

      return root ~ p.data.split(PosixPath.separator)
                          .filter!(a => !a.empty && !a.isDot)
                          .joiner(sep)
                          .to!string();
    }
  }
}


auto asPosixPath(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  return PathType(p.posixData);
}

auto asWindowsPath(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  return PathType(p.windowsData);
}

auto asNormalizedPath(DestType = SrcType, SrcType)(auto ref in SrcType p)
  if(isSomePath!DestType && isSomePath!SrcType)
{
  return DestType(p.normalizedData);
}


/// Whether the path is absolute.
auto isAbsolute(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  // If the path has a root, it is absolute.
  return !p.root.empty;
}

///
unittest
{
  assert(!WindowsPath("").isAbsolute);
  assert(!WindowsPath("/Hello/World").isAbsolute);
  assert(WindowsPath("C:/Hello/World").isAbsolute);
  assert(!WindowsPath("foo/bar.exe").isAbsolute);
  assert(!PosixPath("").isAbsolute);
  assert(PosixPath("/Hello/World").isAbsolute);
  assert(!PosixPath("C:/Hello/World").isAbsolute);
  assert(!PosixPath("foo/bar.exe").isAbsolute);
}


auto absolute(PathType)(auto ref in PathType p, lazy PathType parent = cwd().asNormalizedPath!PathType())
{
  if(p.isAbsolute) {
    return p;
  }

  return parent ~ p;
}

/// TODO
unittest
{
  assertEqual(WindowsPath("bar/baz.exe").absolute(WindowsPath("C:/foo")), WindowsPath("C:/foo/bar/baz.exe"));
  assertEqual(WindowsPath("C:/foo/bar.exe").absolute(WindowsPath("C:/baz")), WindowsPath("C:/foo/bar.exe"));
}


/// Returns: The parts of the path as an array.
auto parts(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  static if(is(PathType == WindowsPath))
  {
    auto prefix = "";
  }
  else static if(is(PathType == PosixPath))
  {
    auto prefix = p.root;
  }
  auto theSplit = p.normalizedData.split(PathType.separator);
  return (prefix ~ theSplit).filter!(a => !a.empty);
}

///
unittest
{
  assertEqual(Path().parts, ["."]);
  assertEqual(Path("./.").parts, ["."]);

  assertEqual(WindowsPath("C:/hello/world").parts, ["C:", "hello", "world"]);
  assertEqual(WindowsPath(`hello/.\world.exe.xml`).parts, ["hello", "world.exe.xml"]);
  assertEqual(WindowsPath("C:/hello/world.exe.xml").parts, ["C:", "hello", "world.exe.xml"]);

  assertEqual(PosixPath("hello/world.exe.xml").parts, ["hello", "world.exe.xml"]);
  assertEqual(PosixPath("/hello/.//world.exe.xml").parts, ["/", "hello", "world.exe.xml"]);
  assertEqual(PosixPath("/hello\\ world.exe.xml").parts, ["/", "hello\\ world.exe.xml"]);
}


auto parent(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  auto theParts = p.parts.map!(a => PathType(a)).array;
  if(theParts.length > 1) {
    return theParts[0 .. $ - 1].reduce!((a, b){ return a ~ b;});
  }
  return PathType();
}

///
unittest
{
  assertEqual(Path().parent, Path());
  assertEqual(Path("IHaveNoParents").parent, Path());
  assertEqual(WindowsPath("C:/hello/world").parent, WindowsPath(`C:\hello`));
  assertEqual(WindowsPath("C:/hello/world/").parent, WindowsPath(`C:\hello`));
  assertEqual(WindowsPath("C:/hello/world.exe.foo").parent, WindowsPath(`C:\hello`));
  assertEqual(PosixPath("/hello/world").parent, PosixPath("/hello"));
  assertEqual(PosixPath("/hello/\\ world/").parent, PosixPath("/hello"));
  assertEqual(PosixPath("/hello.foo.bar/world/").parent, PosixPath("/hello.foo.bar"));
}


/// /foo/bar/baz/hurr.durr => { Path("/foo/bar/baz"), Path("/foo/bar"), Path("/foo"), Path("/") }
auto parents(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  auto theParts = p.parts.map!(x => PathType(x)).array;
  return iota(theParts.length - 1, 0, -1).map!(x => theParts.take(x)
                                                            .reduce!((a, b){ return a ~ b; }));
}

///
unittest
{
  assertEmpty(WindowsPath().parents);
  assertEmpty(WindowsPath(".").parents);
  assertEmpty(WindowsPath("foo.txt").parents);
  assertEqual(WindowsPath("C:/hello/world").parents, [ WindowsPath(`C:\hello`), WindowsPath(`C:\`) ]);
  assertEqual(WindowsPath("C:/hello/world/").parents, [ WindowsPath(`C:\hello`), WindowsPath(`C:\`) ]);

  assertEmpty(PosixPath().parents);
  assertEmpty(PosixPath(".").parents);
  assertEmpty(PosixPath("foo.txt").parents);
  assertEqual(PosixPath("/hello/world").parents, [ PosixPath("/hello"), PosixPath("/") ]);
  assertEqual(PosixPath("/hello/world/").parents, [ PosixPath("/hello"), PosixPath("/") ]);
}


/// The name of the path without any of its parents.
auto name(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  import std.algorithm : min;

  auto data = p.posixData;
  auto i = min(data.lastIndexOf('/') + 1, data.length);
  return data[i .. $];
}

///
unittest
{
  assertEqual(WindowsPath().name, ".");
  assertEqual(WindowsPath("").name, ".");
  assertEmpty(WindowsPath("/").name);
  assertEqual(WindowsPath("/hello").name, "hello");
  assertEqual(WindowsPath("C:\\hello").name, "hello");
  assertEqual(WindowsPath("C:/hello/world.exe").name, "world.exe");
  assertEqual(WindowsPath("hello/world.foo.bar.exe").name, "world.foo.bar.exe");

  assertEqual(PosixPath().name, ".");
  assertEqual(PosixPath("").name, ".");
  assertEmpty(PosixPath("/").name, "/");
  assertEqual(PosixPath("/hello").name, "hello");
  assertEqual(PosixPath("C:\\hello").name, "C:\\hello");
  assertEqual(PosixPath("/foo/bar\\ baz.txt").name, "bar\\ baz.txt");
  assertEqual(PosixPath("C:/hello/world.exe").name, "world.exe");
  assertEqual(PosixPath("hello/world.foo.bar.exe").name, "world.foo.bar.exe");
}


/// The extension of the path including the leading dot.
///
/// Examples: The extension of "hello.foo.bar.exe" is ".exe".
auto extension(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  auto data = p.name;
  auto i = data.lastIndexOf('.');
  if(i < 0) {
    return "";
  }
  if(i + 1 == data.length) {
    // This prevents preserving the dot in empty extensions such as `hello.foo.`.
    ++i;
  }
  return data[i .. $];
}

///
unittest
{
  assertEmpty(Path().extension);
  assertEmpty(Path("").extension);
  assertEmpty(Path("/").extension);
  assertEmpty(Path("/hello").extension);
  assertEmpty(Path("C:/hello/world").extension);
  assertEqual(Path("C:/hello/world.exe").extension, ".exe");
  assertEqual(Path("hello/world.foo.bar.exe").extension, ".exe");
}


/// All extensions of the path.
auto extensions(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  import std.algorithm : splitter, filter;
  import std.range : dropOne;

  auto result = p.name.splitter('.').filter!(a => !a.empty);
  if(!result.empty) {
    result = result.dropOne;
  }
  return result.map!(a => '.' ~ a).array;
}

///
unittest
{
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
/// Examples: The full extension of "hello.foo.bar.exe" would be ".foo.bar.exe".
auto fullExtension(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  auto data = p.name;
  auto i = data.indexOf('.');
  if(i < 0) {
    return "";
  }
  if(i + 1 == data.length) {
    // This prevents preserving the dot in empty extensions such as `hello.foo.`.
    ++i;
  }
  return data[i .. $];
}

///
unittest
{
  assertEmpty(Path().fullExtension);
  assertEmpty(Path("").fullExtension);
  assertEmpty(Path("/").fullExtension);
  assertEmpty(Path("/hello").fullExtension);
  assertEmpty(Path("C:/hello/world").fullExtension);
  assertEqual(Path("C:/hello/world.exe").fullExtension, ".exe");
  assertEqual(Path("hello/world.foo.bar.exe").fullExtension, ".foo.bar.exe");
}


/// The name of the path without its extension.
auto stem(PathType)(auto ref in PathType p)
  if(isSomePath!PathType)
{
  auto data = p.name;
  auto i = data.indexOf('.');
  if(i < 0) {
    return data;
  }
  if(i + 1 == data.length) {
    // This prevents preserving the dot in empty extensions such as `hello.foo.`.
    ++i;
  }
  return data[0 .. i];
}

///
unittest
{
  assertEqual(Path().stem, ".");
  assertEqual(Path("").stem, ".");
  assertEqual(Path("/").stem, "");
  assertEqual(Path("/hello").stem, "hello");
  assertEqual(Path("C:/hello/world").stem, "world");
  assertEqual(Path("C:/hello/world.exe").stem, "world");
  assertEqual(Path("hello/world.foo.bar.exe").stem, "world");
}


/// Create a path from $(D p) that is relative to $(D parent).
auto relativeTo(PathType)(auto ref in PathType p, in auto ref PathType parent)
  if(isSomePath!PathType)
{
  auto ldata = p.normalizedData;
  auto rdata = parent.normalizedData;
  if(!ldata.startsWith(rdata)) {
    throw new PathException(format("'%s' is not a subpath of '%s'.", ldata, rdata));
  }
  auto sliceStart = rdata.length;
  if(rdata.length != ldata.length) {
    // Remove trailing path separator.
    ++sliceStart;
  }
  auto result = ldata[sliceStart .. $];
  return result.isDot ? PathType(".") : PathType(result);
}

///
unittest
{
  import std.exception : assertThrown;

  assertEqual(Path("C:/hello/world.exe").relativeTo(Path("C:/hello")), Path("world.exe"));
  assertEqual(Path("C:/hello").relativeTo(Path("C:/hello")), Path());
  assertEqual(Path("C:/hello/").relativeTo(Path("C:/hello")), Path());
  assertEqual(Path("C:/hello").relativeTo(Path("C:/hello/")), Path());
  assertEqual(WindowsPath("C:/foo/bar/baz").relativeTo(WindowsPath("C:/foo")), WindowsPath(`bar\baz`));
  assertEqual(PosixPath("C:/foo/bar/baz").relativeTo(PosixPath("C:/foo")), PosixPath("bar/baz"));
  assertThrown!PathException(Path("a").relativeTo(Path("b")));
}


/// Whether the given path matches the given glob-style pattern
auto match(PathType, Pattern)(auto ref in PathType p, Pattern pattern)
  if(isSomePath!PathType)
{
  import std.path : globMatch;

  return p.normalizedData.globMatch!(PathType.caseSensitivity)(pattern);
}

///
unittest
{
  assert(Path().match("*"));
  assert(Path("").match("*"));
  assert(Path(".").match("*"));
  assert(Path("/").match("*"));
  assert(Path("/hello").match("*"));
  assert(Path("/hello/world.exe").match("*"));
  assert(Path("/hello/world.exe").match("*.exe"));
  assert(!Path("/hello/world.exe").match("*.zip"));
  assert(WindowsPath("/hello/world.EXE").match("*.exe"));
  assert(!PosixPath("/hello/world.EXE").match("*.exe"));
}


/// Whether the path exists or not. It does not matter whether it is a file or not.
bool exists(in Path p) {
  return std.file.exists(p.data);
}

///
unittest
{
}


/// Whether the path is an existing directory.
bool isDir(in Path p) {
  return std.file.isDir(p.data);
}

///
unittest
{
}


/// Whether the path is an existing file.
bool isFile(in Path p) {
  return std.file.isFile(p.data);
}

///
unittest
{
}


/// Whether the given path $(D p) points to a symbolic link (or junction point in Windows).
bool isSymlink(in Path p) {
  return std.file.isSymlink(p.normalizedData);
}

///
unittest
{
}


// Resolve all ".", "..", and symlinks.
Path resolved(in Path p) {
  return Path(Path(std.path.absolutePath(p.data)).normalizedData);
}

///
unittest
{
  assertNotEqual(Path(), Path().resolved());
}


/// The absolute path to the current working directory with symlinks and friends resolved.
Path cwd() {
  return Path(std.file.getcwd());
}

///
unittest
{
  assertNotEmpty(cwd().data);
}


/// The path to the current executable.
Path currentExePath() {
  return Path(std.file.thisExePath()).resolved();
}

///
unittest
{
  assertNotEmpty(currentExePath().data);
}


void chdir(in Path p) {
  std.file.chdir(p.normalizedData);
}

///
unittest
{
}


/// Generate an input range of Paths that match the given pattern.
auto glob(PatternType)(auto ref in Path p, PatternType pattern, SpanMode spanMode = SpanMode.shallow) {
  return std.file.dirEntries(p.normalizedData, pattern, spanMode).map!(a => Path(a.name));
}

///
unittest
{
  assertNotEmpty(currentExePath().parent.glob("*"));
  assertNotEmpty(currentExePath().parent.glob("*", SpanMode.shallow));
  assertNotEmpty(currentExePath().parent.glob("*", SpanMode.breadth));
  assertNotEmpty(currentExePath().parent.glob("*", SpanMode.depth));
}


auto open(in Path p, in char[] openMode = "rb") {
  static import std.stdio;

  return std.stdio.File(p.normalizedData, openMode);
}

///
unittest
{
}


/// Copy a file to some destination.
/// If the destination exists and is a file, it is overwritten. If it is an existing directory, the actual destination will be ($D dest ~ src.name).
/// Behaves like std.file.copy except that $(D dest) does not have to be a file.
/// See_Also: copyTo(in Path, in Path)
void copyFileTo(in Path src, in Path dest) {
  if(dest.exists && dest.isDir) {
    std.file.copy(src.normalizedData, (dest ~ src.name).normalizedData);
  }
  else {
    std.file.copy(src.normalizedData, dest.normalizedData);
  }
}

///
unittest
{
}


/// Copy a file or directory to a target file or directory.
///
/// This function essentially behaves like the unix shell command `cp -r` with just asingle source input.
///
/// Params:
///   src = The path to a file or a directory.
///   dest = The path to a file or a directory. If $(D src) is a directory, $(D dest) must be an existing directory.
///
/// Throws: PathException
void copyTo(alias copyCondition = (a, b){ return true; })(in Path src, in Path dest) {
  if(!src.exists) {
    throw new PathException(format("The source path does not exist: %s", src));
  }

  if(src.isFile) {
    if(copyCondition(src, dest)) src.copyFileTo(dest);
    return;
  }

  if(!dest.exists) {
    dest.mkdir(false);
  }
  else if(dest.isFile) {
    // At this point we know that src must be a dir.
    throw new PathException(format("Since the source path is a directory, the destination must be a directory as well. Source: %s | Destination: %s", src, dest));
  }

  foreach(srcFile; src.glob("*", SpanMode.breadth).filter!(a => !a.isDir)) {
    auto destFile = dest ~ srcFile.relativeTo(src);
    if(!copyCondition(srcFile, destFile)) {
      continue;
    }
    if(!destFile.exists) {
      destFile.parent.mkdir(true);
    }
    srcFile.copyFileTo(destFile);
  }
}

///
unittest
{
}


alias copyToIfNewer = copyTo!((src, dest){
  import std.datetime : SysTime;
  SysTime _, src_modTime, dest_modTime;
  std.file.getTimes(src.normalizedData, _, src_modTime);
  std.file.getTimes(dest.normalizedData, _, dest_modTime);
  return src_modTime < dest_modTime;
});


/// Remove path from filesystem. Similar to unix `rm`. If the path is a dir, will reecursively remove all subdirs by default.
void remove(in Path p, bool recursive = true) {
  if(p.isFile) {
    std.file.remove(p.normalizedData);
  }
  else if(recursive) {
    std.file.rmdirRecurse(p.normalizedData);
  }
  else {
    std.file.rmdir(p.normalizedData);
  }
}

///
unittest
{
}


///
void mkdir(in Path p, bool parents = true) {
  if(parents) {
    std.file.mkdirRecurse(p.normalizedData);
  }
  else {
    std.file.mkdir(p.normalizedData);
  }
}

///
unittest
{
}


auto readFile(in Path p) {
  return std.file.read(p.normalizedData);
}

///
unittest
{
}


///
auto readFile(S)(in Path p)
  if(isSomeString!S)
{
  return cast(S)std.file.readText!S(p.normalizedData);
}

///
unittest
{
}


///
void writeFile(in Path p, const void[] buffer) {
  std.file.write(p.normalizedData, buffer);
}

///
unittest
{
}


///
void appendFile(in Path p, in void[] buffer) {
  std.file.append(p.normalizedData, buffer);
}

///
unittest
{
}
