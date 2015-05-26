/++
  Authors:
    Manuzor

  ToDo:
    - Path().open(...)
+/
module pathlib;

static import std.path;
static import std.file;
static import std.uni;
import std.array      : array, replace, replaceLast;
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


/// Whether $(D str) can be represented by ".".
bool isDot(StringType)(auto ref in StringType str)
  if(isSomeString!StringType)
{
  if(str.length && str[0] != '.') {
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
auto isDot(PathType)(auto ref in PathType p)
  if(!isSomeString!PathType)
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
auto root(PathType)(auto ref in PathType p) {
  auto data = p.data;

  static if(is(PathType == WindowsPath))
  {
    if(data.length > 1 && data[1] == ':') {
      return data[0..2];
    }
  }
  else // Assume PosixPath
  {
    if(data.length > 0 && data[0] == '/') {
      return data[0..1];
    }
  }

  return "";
}

///
unittest {
  assertEqual(WindowsPath("").root, "");
  assertEqual(PosixPath("").root, "");
  assertEqual(WindowsPath("C:/Hello/World").root, "C:");
  assertEqual(WindowsPath("/Hello/World").root, "");
  assertEqual(PosixPath("/hello/world").root, "/");
  assertEqual(PosixPath("C:/hello/world").root, "");
}


/// The drive of the path $(D p).
/// Note: Non-Windows platforms have no concept of "drives".
auto drive(PathType)(auto ref in PathType p) {
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
unittest {
  assertEqual(WindowsPath("").drive, "");
  assertEqual(WindowsPath("/Hello/World").drive, "");
  assertEqual(WindowsPath("C:/Hello/World").drive, "C:");
  assertEqual(PosixPath("").drive, "");
  assertEqual(PosixPath("/Hello/World").drive, "");
  assertEqual(PosixPath("C:/Hello/World").drive, "");
}


/// Returns: The path data using forward slashes, regardless of the current platform.
auto posixData(PathType)(auto ref in PathType p) {
  if(p.isDot) {
    return ".";
  }
  auto root = p.root;
  auto result = p.data[root.length..$].replace("\\", "/").squeeze("/");
  if(result.length > 1 && result[$ - 1] == '/') {
    result = result[0..$ - 1];
  }
  while(result.endsWith("/.")) {
    result = result[0 .. $ - 2].squeeze("/");
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
  assertEqual(Path("hello/.").posixData, "hello");
  assertEqual(Path("hello/././.").posixData, "hello");
  assertEqual(Path("hello/././/.//").posixData, "hello");
}


/// Returns: The path data using backward slashes, regardless of the current platform.
auto windowsData(PathType)(auto ref in PathType p) {
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
auto normalizedData(PathType)(auto ref in PathType p)
  if(is(PathType == PosixPath) || is(PathType == WindowsPath))
{
  static if(is(PathType == PosixPath)) {
    return p.posixData;
  }
  else static if(is(PathType == WindowsPath)) {
    return p.windowsData;
  }
}


auto asPosixPath(PathType)(auto ref in PathType p) {
  return PathType(p.posixData);
}

auto asWindowsPath(PathType)(auto ref in PathType p) {
  return PathType(p.windowsData);
}

auto asNormalizedPath(PathType)(auto ref in PathType p) {
  return PathType(p.normalizedData);
}


/// Whether the path is absolute.
auto isAbsolute(PathType)(auto ref in PathType p) {
  // Ifthe path has a root or a drive, it is absolute.
  return !p.root.empty || !p.drive.empty;
}


/// Returns: The parts of the path as an array.
auto parts(PathType)(auto ref in PathType p) {
  string[] theParts;
  auto root = p.root;
  if(!root.empty) {
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


auto parent(PathType)(auto ref in PathType p) {
  auto theParts = p.parts.map!(a => PathType(a));
  if(theParts.length > 1) {
    return theParts[0 .. $ - 1].reduce!((a, b){ return a ~ b;});
  }
  return PathType();
}

///
unittest {
  assertEqual(Path().parent, Path());
  assertEqual(Path("IHaveNoParents").parent, Path());
  assertEqual(WindowsPath("C:/hello/world").parent, WindowsPath(`C:\hello`));
  assertEqual(WindowsPath("C:/hello/world/").parent, WindowsPath(`C:\hello`));
  assertEqual(WindowsPath("C:/hello/world.exe.foo").parent, WindowsPath(`C:\hello`));
  assertEqual(PosixPath("/hello/world").parent, PosixPath("/hello"));
  assertEqual(PosixPath("/hello/\\/world/").parent, PosixPath("/hello"));
  assertEqual(PosixPath("/hello.foo.bar/world/").parent, PosixPath("/hello.foo.bar"));
}


/// Returns: The parts of the path as an array, without the last component.
auto parents(PathType)(auto ref in PathType p) {
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
auto name(PathType)(auto ref in PathType p) {
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
auto extension(PathType)(auto ref in PathType p) {
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
auto extensions(PathType)(auto ref in PathType p) {
  import std.algorithm : splitter, filter;
  import std.range : dropOne;

  auto result = p.name.splitter('.').filter!(a => !a.empty);
  if(!result.empty) {
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
auto fullExtension(PathType)(auto ref in PathType p) {
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
unittest {
  assertEmpty(Path().fullExtension);
  assertEmpty(Path("").fullExtension);
  assertEmpty(Path("/").fullExtension);
  assertEmpty(Path("/hello").fullExtension);
  assertEmpty(Path("C:/hello/world").fullExtension);
  assertEqual(Path("C:/hello/world.exe").fullExtension, ".exe");
  assertEqual(Path("hello/world.foo.bar.exe").fullExtension, ".foo.bar.exe");
}


/// The name of the path without its extension.
auto stem(PathType)(auto ref in PathType p) {
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
unittest {
  assertEqual(Path().stem, ".");
  assertEqual(Path("").stem, ".");
  assertEqual(Path("/").stem, "");
  assertEqual(Path("/hello").stem, "hello");
  assertEqual(Path("C:/hello/world").stem, "world");
  assertEqual(Path("C:/hello/world.exe").stem, "world");
  assertEqual(Path("hello/world.foo.bar.exe").stem, "world");
}


/// Whether the given path matches the given glob-style pattern
auto match(PathType, Pattern)(auto ref in PathType p, Pattern pattern) {
  import std.path : globMatch;

  return p.normalizedData.globMatch!(PathType.caseSensitivity)(pattern);
}

///
unittest {
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
unittest {
}


/// Whether the path is an existing directory.
bool isDir(in Path p) {
  return p.exists && std.file.isDir(p.data);
}

///
unittest {
}


/// Whether the path is an existing file.
bool isFile(in Path p) {
  return p.exists && std.file.isFile(p.data);
}

///
unittest {
}


/// Whether the given path $(D p) points to a symbolic link (or junction point in Windows).
bool isSymlink(in Path p) {
  return std.file.isSymlink(p.normalizedData);
}

///
unittest {
}


// Resolve all ".", "..", and symlinks.
Path resolve(in Path p) {
  return Path(Path(std.path.absolutePath(p.data)).normalizedData);
}

///
unittest {
  assertNotEqual(Path(), Path().resolve());
}


/// The absolute path to the current working directory with symlinks and friends resolved.
Path cwd() {
  return Path().resolve();
}

///
unittest {
  assertNotEmpty(cwd().data);
}


/// The path to the current executable.
Path currentExePath() {
  return Path(std.file.thisExePath()).resolve();
}

///
unittest {
  assertNotEmpty(currentExePath().data);
}


void mkdir(in Path p) {
  std.file.mkdirRecurse(p.normalizedData);
}


void chdir(in Path p) {
  std.file.chdir(p.normalizedData);
}


/// Generate an array of Paths that match the given pattern in and beneath the given path.
auto glob(PatternType)(auto ref in Path p, PatternType pattern) {
  import std.algorithm : filter;
  import std.file : SpanMode;

  return std.file.dirEntries(p.normalizedData, pattern, SpanMode.shallow)
         .map!(a => Path(a.name));
}

///
unittest {
  assertNotEmpty(currentExePath().parent.glob("*"));
}


/// Generate an array of Paths that match the given pattern in and beneath the given path.
auto rglob(PatternType)(auto ref in Path p, PatternType pattern) {
  import std.algorithm : filter;
  import std.file : SpanMode;

  return std.file.dirEntries(p.normalizedData, pattern, SpanMode.breadth)
         .map!(a => Path(a.name));
}

///
unittest {
  assertNotEmpty(currentExePath().parent.rglob("*"));
}


auto open(in Path p, in char[] openMode = "rb") {
  static import std.stdio;

  return std.stdio.File(p.normalizedData, openMode);
}

///
unittest {
}


void copy(in Path from, in Path to) {
  std.file.copy(from.normalizedData, to.normalizedData);
}

///
unittest {
}


bool copyIfNewer(in Path from, in Path to) {
  if(!to.exists) {
    copy(from, to);
    return true;
  }

  import std.datetime : SysTime;
  SysTime _, from_modTime, to_modTime;
  std.file.getTimes(from.normalizedData, _, from_modTime);
  std.file.getTimes(to.normalizedData, _, to_modTime);
  if(from_modTime > to_modTime) {
    copy(from, to);
    return true;
  }
  return false;
}


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
unittest {
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
unittest {
}


mixin template PathCommon(PathType, StringType, alias theSeparator, alias theCaseSensitivity)
  if(isSomeString!StringType && isSomeChar!(typeof(theSeparator)))
{
  StringType data = ".";

  ///
  unittest {
    assert(PathType().data != "");
    assert(PathType("123").data == "123");
    assert(PathType("C:///toomany//slashes!\\").data == "C:///toomany//slashes!\\");
  }


  /// Used to separate each path segment.
  alias separator = theSeparator;

  /// A value of std.path.CaseSensetive whether this type of path is case sensetive or not.
  alias caseSensitivity = theCaseSensitivity;


  /// Concatenate a path and a string, which will be treated as a path.
  auto opBinary(string op : "~", InStringType)(auto ref in InStringType str) const
    if(isSomeString!InStringType)
  {
    return this ~ PathType(str);
  }

  /// Concatenate two paths.
  auto opBinary(string op : "~")(auto ref in PathType other) const {
    auto p = PathType(data);
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
  void opOpAssign(string op : "~")(auto ref in PathType other) {
    auto l = PathType(this.normalizedData);
    auto r = PathType(other.normalizedData);

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
      sep = [separator];
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
  bool opBinary(string op : "==")(auto ref in PathType other) const {
    auto l = this.data.empty ? "." : this.data;
    auto r = other.data.empty ? "." : other.data;
    static if(theCaseSensitivity == std.path.CaseSensetive.no) {
      return std.uni.sicmp(l, r);
    }
    else {
      return std.algorithm.cmp(l, r);
    }
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
  mixin PathCommon!(WindowsPath, string, '\\', std.path.CaseSensitive.no);

  version(Windows) {
    /// Overload conversion `to` for Path => std.file.DirEntry.
    auto opCast(To : std.file.DirEntry)() const {
      return To(this.normalizedData);
    }

    ///
    unittest {
      auto d = cwd().to!(std.file.DirEntry);
    }
  }
}


struct PosixPath
{
  mixin PathCommon!(PosixPath, string, '/', std.path.CaseSensitive.yes);

  version(Posix) {
    /// Overload conversion `to` for Path => std.file.DirEntry.
    auto opCast(To : std.file.DirEntry)() const {
      return To(this.normalizedData);
    }

    ///
    unittest {
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
