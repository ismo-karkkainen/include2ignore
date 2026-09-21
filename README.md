# include2ignore

A Ruby gem including a program that takes a list of file name rules to include, a directory, and produces a list of files to ignore. Optionally takes a list of file name rules to skip.

## Overview

Ignoring files is an essential feature when you need to take some files and package them in some manner, and ensure that other files are not packaged. You have files you know you want, files you know you do not want, and then some other files that may be lying around at the time of the packaging.

If you have a list of files to ignore, you can state known undesired files to reject. If you have a list of files to include, you have a known desired files to select. In both cases unknown files may be present and get treated differently.

With ignore file, if you have unexpected files, they might not get rejected unless they are named like files to reject. Extra files ending up in the package typically means the package still works, but anyone capable of exploring the contents may find the unexpected files. Harmfulness depends on the contents, and is discovered later on.

With include file, if you have unexpected files, they might be rejected unless they are named like files to include. Omitting needed files possibly means the package does not work, if packaging process succeeds at all. Issues are discovered early on.

In some cases, like with `.dockerignore` you can ignore everything and add exceptions, turning the ignore file essentially into a list of includes. That is not supported in all tools. I personally prefer including only what is known to be needed. Hence this tool.

Sometimes you can place your files so that the ignore file is not needed, such as placing the Helm chart sources under a sub-directory with nothing else in it.

Since the tool in practice finds the files that do not match the input file, you can give it an ignore file and the output file is what would be included given the ignore file. Hence you can use it to check if your ignore file covers what it should.

## Usage

I must point out that taking a list of files to include, and converting it to list of files to ignore, results in an ignore file that is valid for the files that were present at the time the tool was run. Passing the ignore file to someone else no longer guarantees in any way that the other person running the packaging commands does not end up with extra files in the package. Running the include2ignore conversion just before packaging is needed to avoid accidental inclusion of files.

Save an include file into the repository. Run the tool and specify via arguments what output file you want using which directory as base.

The include file is a list of patterns that are matched against the files in the directory. A `#` starts a comment line, `!` starts a line that excludes files matching the pattern. A `**` means one or more directories, and `*` is an arbitrary part of a file name. See program help for detailed description.

An exclusion pattern indicates a directory or a file that will always be excluded, and is not searched. Therefore any pattern that would otherwise include a file inside an excluded directory will include nothing inside the directory. Use with directories such as ".git" or "node_modules".

An example of an include file:

```text
# Typical exclusions.
!.git
!coverage
# Ending "/" indicates this is a directory name, not a file.
bin/
# File with extension in any subdirectory of lib but not in lib.
lib/**/*.rb
# Explicitly named file.
/lib/include2ignore.rb
# File (or directory) at processed directory.
/LICENSE.txt
# Whitespace is kept, equals "  dir or file   ".
  dir or file   
# Pattern starts with "!"
\!included!.txt
# Starts with "#", contains "\". Equals "#unlikely\filename.ext".
\#unlikely\\filename.ext
# Pattern has "*" as part of file name. Equals "file*name".
file\*name
# As part of file name, "**" equals "*". Equals "some*name.txt".
some**name.txt
```

If symbolic links require special treatment, use dir and file link arguments to match what the tool does. Use skip list file to avoid searching directories, for example.

The format can be used to configure the output so that it starts with given lines, and each line has stated prefix. So if you specify header string `key:` and line prefix `- ` then output would pass for YAML with key and array-value, subject to the contents of each line. The format can differentiate between cases where include or ignore line counts would have majority, and the output is selected accordingly to minimize the number of lines in the output file.

## License

Copyright © 2026 Ismo Kärkkäinen for files that have not been produced using generative AI.

Licensed under Universal Permissive License. See LICENSE.txt.
