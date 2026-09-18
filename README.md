# include2ignore

A Ruby gem including a program that takes a list of files to include, a directory, and produces a list of files to ignore.

## Overview

Ignoring files, whether for git, docker, or any other tool that supports a ignore file is an essential feature. Required to avoid unnecessary files or to keep from adding files you should not, such as files with creadentials that should not be included in the version control nor be included in container images.

After a project has continued long enough, you have in the clone of a repository the files you have in version control, and possibly other files lying around. From the point of view of a container image contents, or a Helm chart, or whatever you need to build from the repository, you have:

- Files in version control a build target needs.
- Files in version control not needed by a build target.
- Files outside version control.

Rather than tell for everything what that build must ignore, maintain a list of what each build target must include, and everything else is to be ignored. You can add files that are not needed by the particular build, and the include file remains the same. What you must remember, is to run the `include2ignore` after new files have been added. Using [git hooks](https://githooks.com) may be useful in that regard.

Some tools support ignoring everything, and then adding exceptions, which allows the ignore file to be in practice the include file that is used here. Others do not, for example [.helmignore](https://helm.sh/docs/chart_template_guide/helm_ignore_file/) files at the time of writing. Sometimes you can place your files so that the ignore file is not needed, such as placing the Helm chart source into a sub-directory.

## Usage

Save an include file into the repository root directory. Run the tool and specify via arguments what output file you want.

The include file is a list of patterns that are matched against the files in the directory. The first character in the line determines how the line is processed. Special characters are:

- A "#" at the beginning of a line starts a comment to the end of the line. No special meaning elsewhere.
- A "!" at the beginning of a line starts an exclusion pattern. No special meaning elsewhere.
- A "\" ignores any special meaning for next character. Use when your file name starts with "#" or "!". It can also be used to keep trailing spaces and include line breaks into a pattern.

An exclusion pattern indicates a directory or a file that will always be excluded, and is not searched. Therefore any pattern that would otherwise include a file inside an excluded directory will include nothing inside the directory. Use with directories such as ".git" or "node_modules".

An example of an include file:

```text
# Expected exclusions.
!.git
!node_modules
# Ending "/" indicates this is a directory name, not a file.
src/
# Trailing whilespace is trimmed, equals "  dir_or_file".
  dir_or_file   
# Whitespace within name is kept.
dir name with speces/something.extension
# Use "\" to keep trailing whilespace. Equals "trailing/retained   ".
trailing/retained  \ 
# Pattern starts with "!"
\!included!.txt
# Starts with "#", contains "\". Equals "#unlikely\filename.ext".
\#unlikely\\filename.ext
```

Typically you would run the tool at the root of the repository to produce a file in the same directory, using the current directory contents for processing. To check all is as expected, take a diff of the output file committed to the version control.

```sh
include2ignore -i dockerinclude -o .dockerignore
git diff .dockerignore
```

Random files lying around will end up in the ignore file, and hence their names to version control, if you commit the ignore file. On the other hand, to ensure a human has checked the output, running `include2ignore` in CI and existing with an error if differences are found may be advisable. Random files that have not been committed will then cause a difference in CI stage.

## License

Copyright © 2026 Ismo Kärkkäinen for files that have not been produced using generative AI.

Licensed under Universal Permissive License. See LICENSE.txt.
