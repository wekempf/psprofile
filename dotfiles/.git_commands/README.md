# Writing Git Commands

Any language may be used, just need an executable named `git-*` where '*' is the command name. Prefer using bash scripts
for portability.

`git-sh-setup` [in bash scripts provides](https://www.kernel.org/pub/software/scm/git/docs/git-sh-setup.html) useful
functions and options parsing. Tips for using `git-sh-setup`:

1. Usage syntax
   1. Set `OPTIONS_SPEC` to a string that describes the command and it's options.
      1. Use `[options]` to indicate where options go.
      2. `arg_name` for a required, singular arg
      3. `[arg_name]` for an optional, singular arg
      4. `arg_name...` for a required arg of which there can be many
      5. `[arg_name...]` for an option arg of which there can be many
         1. `arg_name` should be a descriptive, short name, in lower, snake_case
2. A nicely formatted list of options
   1. Using the syntax described in [the documentation](https://www.kernel.org/pub/software/scm/git/docs/git-sh-setup.html)
   2. Having a short description
   3. Showing the default value if there is one
   4. Showing the possible values, if that applies
3. Brief description of any environment variables or config files used

See also [docopt](http://docopt.org/).

`git-sh-setup` uses `rev-parse --parseopt` to rewrite the command line arguments in a standard form that makes parsing
easier.

1. If an option has both a short form and a long form available, the default is to use the short form
   1. This can be changed to use the long form by setting `OPTIONS_STUCKLONG` to a truthy value
2. Options with values are always provided in the form `-x=value` or `--long-x=value`
   1. The provided `getValue` function can be used to parse the value out

```bash
function getValue {
    IFS='=' read -ra parts <<<"$1"
    echo ${parts[1]}
}
```
3. Spacing and appropriate quoting is applied
4. Common bash argument parsing code can be used after the inclusion of `git-sh-setup`

```bash
while test $# != 0; do
    case "$1" in
    --flag) ... ;;
    --option=*) $(getValue $1)) ;;
    --) shift; break ;;
    esac
    shift
done
```