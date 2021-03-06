<!-- [comment]: <> (DO NOT EDIT THIS FILE. EDIT THE TEMPLATE "templates/dox/mulle-brew/README.md.scion") -->
# mulle-brew, C/C++/Objective-C developer sandboxing with homebrew

![Last version](https://img.shields.io/github/tag/mulle-nat/mulle-bootstrap.svg)

[Homebrew](//brew.sh) is the de facto standard package manager of OS X. It is also
available on Linux as [Linuxbrew](linuxbrew.sh).

By default homebrew installs packages system-wide into '/usr/local/' (on OS X). But you can actually clone the [brew repository](https://github.com/Homebrew/brew/) to any place in the filesystem. `brew` will the install packages in that place. This way you can create your own playground development environment of tools and libraries.

**mulle-brew** helps you set-up and share such playgrounds, which it keeps in a folder called `addictions`.

## Advantages

* Keep the runtime and your system clear off temporary downloads.
* Updating brew libraries for one project, doesn't necessarily impact parallel projects
* An easy way to share the required build environments
* A uniform way to access those dependencies via a known name `addictions`


## Installing **mulle-brew**

Install mulle-brew with brew, it makes sense :) :

```
brew install mulle-kybernetik/software/mulle-brew
```

## Install and run hello world using **mulle-brew**

Install hello:

```
mulle-brew init
mulle-brew setting -g -r brews hello
mulle-brew
```

Run hello:

```
mulle-brew run hello
```

What does `mulle-brew run` do ? It adds `${PWD}/addictions/bin` to your PATH shell variable. so that **hello** is found for the duration of this command. You could as well have used `./addictions/bin/hello`. The use of `mulle-brew run` becomes more important later on in more complex scenarios.


## Install some libraries with **mulle-brew** and use them with cc, Xcode and clang

Install **libpng** and **zlib**:

```
mulle-brew init
mulle-brew setting -g -r brews libpng
mulle-brew setting -g -r -a brews zlib
mulle-brew
```

Create a small test program:

```
cat <<EOF > x.c
#include <png.h>
#include <zlib.h>

main()
{
   printf( "png version: %u\n", png_access_version_number());
   printf( "zlib version: %s\n", zlibVersion());
   return( 0);
}
```

#### Using cc

Build it with **cc** and run it:

```
flags="`mulle-brew paths -l cflags`"
cc ${flags} -o x x.c
mulle-brew run ./x
```

If you are running `mulle-brew paths -l cflags` in `/tmp` it will produce this
line:

```
-I/tmp/addictions/include -F/tmp/addictions/Frameworks -L/tmp/addictions/lib -lpng -lpng16 -lz
```

`mulle-brew paths cflags` on its own produces the -I, -F and -L flags. The `-l` option collects all the available libraries from `addictions/lib` and adds them as commandline options.


#### Using cmake


Create a `CMakeLists.txt`:

```
cat <<EOF > CMakeLists.txt
cmake_minimum_required (VERSION 3.0)
project (x)

find_library( PNG_LIBRARY NAMES png)
find_library( ZLIB_LIBRARY NAMES z)

add_executable( x
x.c)

target_link_libraries( x
\${PNG_LIBRARY}
\${ZLIB_LIBRARY}
)
EOF
```

Build it with `cmake` and `make`:

```
mkdir build
cd build
cmake `mulle-brew paths cmake` ..
make
```

> Check with `otool -L x` that indeed the libraries from `addictions/lib` have been picked up.




#### Using Xcode

Create a C tool project `x.xcodeproj` that resides in the same folder as `x.c`. Remove `main.c` and add `x.c`.

Now enrich the xcode project with the **mulle-brew** dependencies header and library paths:

```
mulle-brew xcode add x.xcodeproj
```

You still need to manually add the libraries though.



## Sharing addictions

When you have multiple small projects, it would be nice to share a common `addictions` folder. You can do this with  `mulle-brew defer`. This commands links up the current project directory with its immediate parent. 

The addictions folder will now reside in `../addictions` instead of `./addictions`. Now
if you are already in the habit of using `mulle-brew paths` and `mulle-brew run`, you don't have to modify anything!

You can remove from a master project with `mulle-brew emancipate`.


## Various Playground configurations


### Pure playground, gcc/clang based

You install a complete set of custom tools and libraries. The easiest way then
is to pass `--sysroot` to your tool chain like f.e.

```
PATH=`mulle-brew paths -m path`
gcc --sysroot="`mulle-brew paths -m addictions`"
```

### Mixed playground, gcc/clang based

You use the Xcode supplied toolset, but you want the playground headers and
libraries to override the system files.

```
gcc `mulle-brew paths -m cflags`
```


### Sharing playgrounds with other projects

You might find that you have multiple projects with overlapping dependencies on
brew formula and the duplication becomes tedious. You can create a "master"
playground in the common parent directory with:

```
mulle-brew defer
```

And revert back to a private playground with

```
mulle-brew emancipate
```

Here the use of `mulle-brew paths` comes in handy, as it adapts to the
new position of the `addictions` folder in the filesystem.

## Tips

### Keep a cache of homebrew locally

Cloning **brew** from GitHub for every project can get tedious. You can use a local cache with:

```
mulle-brew config -u "clone_cache" "${HOME}/Library/Caches/mulle-brew"
```

### Hack the shared libraries to use a proper @rpath

...



## GitHub and Mulle kybernetiK

The development is done on [Mulle kybernetiK](https://www.mulle-kybernetik.com/software/git/mulle-bootstrap/master). Releases and bug-tracking are on [GitHub](https://github.com/mulle-nat/mulle-bootstrap).


