
# vim-elixir-exunit

Run ExUnit tests in style :)

Provides functionality:
 - to detect compilation errors/warnings and jump to them.
 - to detect failing/crashing ExUnit tests and just to corresponding positions.
 - shorthand functions to call ExUnit tests.
 - running ExUnit tests in separate XTerm window + job control
 - jumping between test/source file

See Vim-Elixir-IDE for provided shortcuts

## :make support

When running `:make` plugin will show only error messages in quickfix window.


## compilation messages

When using shortcut XXXX - both error and warning messages will be shown.

Shortcut XXXXX will force full recompilation and show all warning/error messages.
