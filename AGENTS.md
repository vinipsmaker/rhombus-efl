# Agent guide

Read `README.md` before using or changing this package. It contains installation instructions, runnable examples, API coverage, ownership rules, and Eo symbol tables.

## Project scope

This is an essential `rhombus/static` binding for EFL, implemented with `rhombus-ffi-lib`. Keep the surface small:

- Bind shared infrastructure and genuinely essential Eo interfaces.
- Use `eo.efl_class_lookup` and `eo.efl_event_lookup` for module-specific classes and events.
- Do not generate per-widget APIs or add bindings for entire EFL modules.
- Keep public modules under the existing `libs`, `eina`, `eo`, `core`, `interfaces`, and `ui` namespaces.

## Change rules

- Match EFL headers exactly, including integer widths, by-value structs/unions, callback signatures, and ownership.
- Use `eina_bool_t` for `Eina_Bool`; it is an unsigned byte, not C `int`.
- Export every new public binding and update `README.md` in the same change.
- Preserve the high-level `on_event`/`off_event` contract: retain the closure and exact C callback pointer, and unregister with that same pointer.
- Keep the native Racket callback compatibility path. Pure ffi2 1.1 fails after invoking `void_t` callbacks; its `_cprocedure` input types must remain a `PairList`.
- Do not replace the Eo constructors with a lookup for `efl_add`; that C API is a macro. Construction must start and end through `_efl_add_internal_start` and `_efl_add_end`, with `~initialize` running between them.
- Do not add automatic unref/delete finalizers without a clear native ownership design. Eo parent and caller references have different rules.
- Update comments and documentation whenever behavior changes.

## Verification

Install or update the linked package, then compile it:

```sh
raco pkg install --auto --link --name rhombus-efl-lib /path/to/rhombus-efl2
raco setup --pkgs rhombus-efl-lib
```

Exercise real EFL calls after changes. Compilation alone does not validate foreign signatures.

At minimum, cover the affected area:

- Eo: class lookup, construction and finalization, parent/reference behavior, property round-trips, and child iteration.
- Events: callback delivery, exact-pointer removal, and no invocation after removal.
- Core: a timer callback that exits `core.efl_loop_begin` with a known exit code.
- Interfaces/UI: construct actual objects and use `ELM_ENGINE=buffer` for a headless window, widgets, geometry, text, content, packing, and click delivery.

The project has no checked-in test suite. Unless tests are explicitly requested, use temporary verification modules outside the source tree rather than adding test scaffolding. Remove generated `efl/compiled` artifacts after verification if they were created by the build.

## Important usage invariants

- Initialize the EFL module before looking up or constructing its classes.
- Set Elementary window geometry after finalization; construction can reset it.
- Unregister event handlers before destroying their target objects.
- Do not let exceptions escape through C callbacks.
- Compare Eo identity with native addresses, not Rhombus wrapper identity. A null native result can be a tagged null pointer rather than `#false`.
- Verify interface support with `efl_isa` when it is not guaranteed by the object's class.
