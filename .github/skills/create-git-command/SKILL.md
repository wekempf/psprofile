---
name: create-git-command
description: Guide for creating a custom git subcommand (a `git-foo` shell script invocable as `git foo`) using git-sh-setup and the OPTIONS_* variables for standard option parsing. Use when asked to create, add, or scaffold a new git command/subcommand.
---

## Where to put the new command

If the destination isn't specified, ask the user where to create the script.
When working in this profile repository, the default location is
`dotfiles/.git_commands/git-<name>` (this folder is symlinked to `~/.git_commands`,
which is on `PATH`).

Do not use the existing scripts already in `dotfiles/.git_commands` as a
reference or template - they predate this skill, contain outdated patterns,
and include a shared helper script that should not be reused. Follow only the
guidance below.

## Naming and invocation

- A script named `git-<name>` anywhere on `PATH` becomes invocable as `git <name>`.
- Use a POSIX `sh` shebang (`#!/bin/sh`) - `git-sh-setup` is a Bourne shell
  library, not PowerShell. On Windows this runs under Git for Windows' bundled
  `sh.exe`.
- The file must be executable (`chmod +x git-<name>`; on Windows, ensure the
  file has no extension so `git <name>` resolves it, and that Git Bash/WSL can
  execute it).

## Standard skeleton

```sh
#!/bin/sh

OPTIONS_KEEPDASHDASH=
OPTIONS_STUCKLONG=t
OPTIONS_SPEC="\
git <name> [options] <args>...
--
h,help    show the help
v,verbose be verbose
n,dry-run dry run only
o,output= write to this file
"
SUBDIRECTORY_OK="yes" . "$(git --exec-path)/git-sh-setup"

while test $# != 0
do
    case "$1" in
    -v|--verbose) verbose=t ;;
    -n|--dry-run) dry_run=t ;;
    -o|--output) shift; output=$1 ;;
    --) shift; break ;;
    *) usage ;;
    esac
    shift
done

require_work_tree
cd_to_toplevel

# command implementation goes here
```

## Control variables (set before sourcing git-sh-setup)

- `OPTIONS_SPEC` - usage line(s), a blank line, `--`, then one
  `shortletter,longname[=]<TAB>description` per line. Drives both parsing and
  the auto-generated `-h`/`--help` output. Omit entirely (along with
  `OPTIONS_KEEPDASHDASH`/`OPTIONS_STUCKLONG`) for a very simple command that
  doesn't need option parsing - set `USAGE`/`LONG_USAGE` instead in that case.
- `OPTIONS_KEEPDASHDASH` - if set, a literal `--` in the arguments is preserved
  instead of being consumed as the options/operands separator.
- `OPTIONS_STUCKLONG` - if set, allows `--option=value` in addition to
  `--option value`.
- `SUBDIRECTORY_OK` - set to `"yes"` to allow running the command from a
  subdirectory of the working tree rather than only from the repo root.
- `NONGIT_OK` - set to allow the command to run even outside a git repository
  (normally `git-sh-setup` requires being inside one).

Source the library with:

```sh
SUBDIRECTORY_OK="yes" . "$(git --exec-path)/git-sh-setup"
```

After sourcing, `git-sh-setup` evaluates `OPTIONS_SPEC` via
`git rev-parse --parseopt`, which normalizes `"$@"` (expanding short/long
flags to a canonical form, handling `--help`) and terminates the option list
with `--`, ready for the `while`/`case` loop shown above.

## Helper functions available after sourcing

`usage`, `die`, `say`, `require_work_tree`, `cd_to_toplevel`,
`is_bare_repository`, `get_author_ident_from_commit`.

## Verifying the result

1. Confirm the script is executable and on `PATH` (`command -v git-<name>` in
   a POSIX shell, or from a fresh PowerShell session where `~/.git_commands`
   is on `PATH`).
2. Run `git <name> --help` and confirm the usage text matches `OPTIONS_SPEC`.
3. Exercise each declared option (including `--option=value` if
   `OPTIONS_STUCKLONG` is set) and confirm behavior, then test the no-option
   default path.
4. If `SUBDIRECTORY_OK` is set, verify the command also works when invoked
   from a subdirectory of a repository, not just the top level.
