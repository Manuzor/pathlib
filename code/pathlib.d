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


/// Returns: The path string using forward slashes, regardless of the current platform.
auto asPosix(PathType)(PathType p) {
  auto root = p.root;
  auto result = p.data[root.length..$].replace("\\", "/").squeeze("/");
  if (result.length > 1 && result[$ - 1] == '/')
    result = result[0..$ - 1];
  return root ~ result;
}

///
unittest {
  assert(Path().asPosix() != "");
  assert(Path("").asPosix() == "", Path("").asPosix());
  assert(Path("/hello/world").asPosix() == "/hello/world");
  assert(Path("/\\hello/\\/////world//").asPosix() == "/hello/world", Path("/\\hello/\\/////world//").asPosix());
  assert(Path(`C:\`).asPosix() == "C:/", Path(`C:\`).asPosix());
  assert(Path(`C:\hello\`).asPosix() == "C:/hello");
  assert(Path(`C:\some windows\/path.exe.doodee`).asPosix() == "C:/some windows/path.exe.doodee");
  assert(Path(`C:\some windows\/path.exe.doodee\\\`).asPosix() == "C:/some windows/path.exe.doodee");
  assert(Path(`C:\some windows\/path.exe.doodee\\\`).asPosix() == Path(Path(`C:\some windows\/path.exe.doodee\\\`).asPosix()).data);
}


// Returns: The root of the path $(D p).
string root(PathType)(PathType p) {
  auto data = p.data;

  static if(is(P == WindowsPath))
  {
    if (data.length > 1 && data[1] == ':') {
      return data[0..2];
    }
  }
  else // Assume posix
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
  assert(WindowsPath("C:/Hello/World").root == "C:");
  assert(WindowsPath("/Hello/World").root == "");
  assert(PosixPath("/Hello/World").root == "/");
  assert(PosixPath("C:/Hello/World").root == "");
}


string drive(PathType)(PathType p) {
  return std.path.driveName(p.data);
}

///
unittest {
  assert(WindowsPath("").drive == "");
  assert(WindowsPath("/Hello/World").drive == "");
  assert(WindowsPath("C:/Hello/World").drive == "C:");
  assert(PosixPath("").drive == "");
  assert(PosixPath("/Hello/World").drive == "");
  assert(PosixPath("C:/Hello/World").drive == "");
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
  return std.path.pathSplitter(p.asPosix).array;
}

///
unittest {
  import std.algorithm : equal;

  assert(Path("C:/hello/world.exe.xml").parts.equal(["C:/", "hello", "world.exe.xml"]));
  assert(Path("/hello/world.exe.xml").parts.equal(["/", "hello", "world.exe.xml"]));
}


mixin template PathImpl()
{
  string data;

  ///
  unittest {
    assert(Path().data != "");
    assert(Path("123").data == "123");
    assert(Path("C:///toomany//slashes!\\").data == "C:///toomany//slashes!\\");
  }


  /// Default construct a path, pointing to the current working directory (absolute path).
  static Path opCall() {
    return Path(std.file.getcwd());
  }

  ///
  unittest {
    assert(Path().isAbsolute);
  }

  /// Construct a path from the given string $(D str).
  static Path opCall(string str) {
    Path p;
    p.data = str;
    return p;
  }

  ///
  unittest {
    static assert(__traits(compiles, Path("/hello/world")));
    static assert(__traits(compiles, "/hello/world".Path));
  }

  /// Concatenate two paths.
  auto opDiv(Path other) const {
    return Path("%s/%s".format(data, other.data));
  }

  ///
  unittest {
    assert((Path("C:/hello") / Path("world.exe.xml")) == Path("C:/hello/world.exe.xml"));
  }


  /// Concatenate a path and a string, which will be treated as a path.
  auto opDiv(string str) const {
    return this / Path(str);
  }

  ///
  unittest {
    assert((Path("C:/hello") / "world.exe.xml") == Path("C:/hello/world.exe.xml"));
  }


  /// Cast the path to a string.
  auto toString() const {
    return this.asPosix();
  }

  ///
  unittest {
    assert(Path("C:/hello/world.exe.xml").to!string == "C:/hello/world.exe.xml", Path("C:/hello/world.exe.xml").to!string);
  }
}


struct WindowsPath
{
  mixin PathImpl;
}


struct PosixPath
{
  mixin PathImpl;
}


version(Windows)
{
  alias Path = WindowsPath;
}
else // Assume posix on non-windows platforms.
{
  alias Path = PosixPath;
}
