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
import std.array    : array, replace, replaceLast;
import std.format   : format;
import std.string   : split, indexOf, empty, squeeze, stripRight;
import std.conv     : to;
import std.typecons : Flag;


debug
{
  void logDebug(T...)(T args) {
    import std.stdio;

    writefln(args);
  }
}


// Returns: The root of the path $(D p).
string root(PathType)(PathType p) {
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
string drive(PathType)(PathType p) {
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


/// Returns: The path string using forward slashes, regardless of the current platform.
auto posixString(PathType)(PathType p) {
  auto root = p.root;
  auto result = p.data[root.length..$].replace("\\", "/").squeeze("/");
  if (result.length > 1 && result[$ - 1] == '/') {
    result = result[0..$ - 1];
  }
  return root ~ result;
}

///
unittest {
  assert(Path().posixString != "");
  assert(Path("").posixString == "", Path("").posixString);
  assert(Path("/hello/world").posixString == "/hello/world");
  assert(Path("/\\hello/\\/////world//").posixString == "/hello/world", Path("/\\hello/\\/////world//").posixString);
  assert(Path(`C:\`).posixString == "C:/", Path(`C:\`).posixString);
  assert(Path(`C:\hello\`).posixString == "C:/hello");
  assert(Path(`C:\/\hello\`).posixString == "C:/hello");
  assert(Path(`C:\some windows\/path.exe.doodee`).posixString == "C:/some windows/path.exe.doodee");
  assert(Path(`C:\some windows\/path.exe.doodee\\\`).posixString == "C:/some windows/path.exe.doodee");
  assert(Path(`C:\some windows\/path.exe.doodee\\\`).posixString == Path(Path(`C:\some windows\/path.exe.doodee\\\`).posixString).data);
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


/// Returns: The parts of the path as a string[].
auto parts(PathType)(PathType p) {
  return std.path.pathSplitter(p.posixString).array;
}

///
unittest {
  import std.algorithm : equal;

  assert(Path("C:/hello/world.exe.xml").parts.equal(["C:/", "hello", "world.exe.xml"]));
  assert(Path("/hello/world.exe.xml").parts.equal(["/", "hello", "world.exe.xml"]));
}


mixin template PathCommon(PathType)
{
  string data;

  ///
  unittest {
    assert(PathType().data != "");
    assert(PathType("123").data == "123");
    assert(PathType("C:///toomany//slashes!\\").data == "C:///toomany//slashes!\\");
  }


  /// Construct a path from the given string $(D str).
  static PathType opCall(string str) {
    PathType p;
    p.data = str;
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


  /// Concatenate two paths.
  auto opDiv(PathType other) const {
    return PathType("%s/%s".format(data, other.data));
  }

  ///
  unittest {
    assert((PathType("C:/hello") / PathType("world.exe.xml")) == PathType("C:/hello/world.exe.xml"), (PathType("C:/hello") / PathType("world.exe.xml")).to!string);
  }


  /// Concatenate a path and a string, which will be treated as a path.
  auto opDiv(string str) const {
    return this / PathType(str);
  }

  ///
  unittest {
    assert((PathType("C:/hello") / "world.exe.xml") == PathType("C:/hello/world.exe.xml"));
  }


  /// Cast the path to a string.
  auto toString() const {
    return this.posixString;
  }

  ///
  unittest {
    assert(PathType("C:/hello/world.exe.xml").to!string == "C:/hello/world.exe.xml", PathType("C:/hello/world.exe.xml").to!string);
  }
}


struct WindowsPath
{
  mixin PathCommon!WindowsPath;
}


struct PosixPath
{
  mixin PathCommon!PosixPath;
}


version(Windows)
{
  alias Path = WindowsPath;
}
else // Assume posix on non-windows platforms.
{
  alias Path = PosixPath;
}
