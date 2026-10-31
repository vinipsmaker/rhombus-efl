# Rhombus EFL

Essential bindings for the Enlightenment Foundation Libraries (EFL), written for `#lang rhombus/static` with `rhombus-ffi-lib`.

The binding is deliberately small. It covers Eina basics, Eo objects and events, the Ecore main loop, common Eo interfaces, and minimal Elementary initialization. Other EFL classes are used through Eo class and event lookup instead of generating bindings for every widget and module.

## Requirements

The verified configuration is:

- Racket 9.2
- `rhombus-lib`
- `rhombus-ffi-lib` 1.1
- EFL 1.28.1, including the Eina, Eo, Efl, Ecore, Evas, and Elementary shared libraries

EFL development headers are useful when looking up class getters, event symbols, and C signatures. They are not needed to compile these Rhombus sources.

The package currently loads version 1 shared-library names, with an unversioned fallback. Other operating systems and EFL versions have not been verified.

## Installation

Install this directory as a linked Racket package:

```sh
raco pkg install --auto --link --name rhombus-efl-lib /path/to/rhombus-efl2
```

Then use the collection from a static Rhombus module:

```rhombus
#lang rhombus/static
import efl
```

Use `import: efl; ffi` or `import: efl; ffi open` when you also need pointer and allocation helpers such as `ffi.ptr_to_uintptr` or `ffi.new`.

## Namespaces

| Namespace | Purpose |
| --- | --- |
| `efl.libs` | Loaded library handles: `eina`, `eo`, `efl`, `ecore`, `evas`, `elementary` |
| `efl.eina` | Eina initialization, errors, booleans, and iterators |
| `efl.eo` | Eo types, construction, ownership, introspection, class/event lookup, and callbacks |
| `efl.core` | Ecore initialization, main-loop operations, exit codes, and timers |
| `efl.interfaces` | Shared Eo interfaces for graphics, text, content, packing, parts, and files |
| `efl.ui` | Minimal Elementary initialization and window autodel support |

The examples below use `import efl`, so names are written with the `efl.` prefix.

## Quick start: a timer and the main loop

This complete example initializes Ecore, constructs an Eo timer, handles its tick event, exits the loop, and cleans up:

```rhombus
#lang rhombus/static
import efl

fun set_timer_interval(object):
  efl.core.efl_loop_timer_interval_set(object, 0.1)

unless efl.core.ecore_init() > 0
| error("could not initialize Ecore")

def loop = efl.core.efl_main_loop_get()
def timer_class:
  efl.eo.efl_class_lookup(efl.libs.ecore, "efl_loop_timer_class_get")
def timer:
  efl.eo.efl_add(timer_class, loop, ~initialize: set_timer_interval)
def tick:
  efl.eo.efl_event_lookup(
    efl.libs.ecore,
    "_EFL_LOOP_TIMER_EVENT_TIMER_TICK"
  )
def handler:
  efl.eo.on_event(timer, tick, fun (event): efl.core.efl_exit(0))

def exit_code = efl.core.efl_loop_begin()

efl.eo.off_event(handler)
efl.eo.efl_del(timer)
efl.core.ecore_shutdown()
println(exit_code)
```

`Efl.Loop.Timer` requires an interval during construction. The `~initialize` callback runs after Eo allocation starts but before finalization, which is the correct place for required construction properties.

## A small Elementary application

The following application creates a window, box, and button. Clicking the button or closing the window exits the main loop:

```rhombus
#lang rhombus/static
import efl

unless efl.ui.elm_init() > 0
| error("could not initialize Elementary")

def loop = efl.core.efl_main_loop_get()
def window:
  efl.eo.efl_add(
    efl.eo.efl_class_lookup(
      efl.libs.elementary,
      "efl_ui_win_class_get"
    ),
    loop
  )

efl.interfaces.efl_text_set(window, "Rhombus EFL")
efl.ui.efl_ui_win_autodel_set(window, #false)
efl.interfaces.efl_gfx_entity_geometry_set(
  window,
  efl.interfaces.eina_rect(40, 40, 360, 160)
)

def box:
  efl.eo.efl_add(
    efl.eo.efl_class_lookup(efl.libs.elementary, "efl_ui_box_class_get"),
    window
  )
def button:
  efl.eo.efl_add(
    efl.eo.efl_class_lookup(efl.libs.elementary, "efl_ui_button_class_get"),
    box
  )

efl.interfaces.efl_text_set(button, "Quit")
efl.interfaces.efl_pack_end(box, button)
efl.interfaces.efl_content_set(window, box)

def clicked:
  efl.eo.efl_event_lookup(efl.libs.evas, "_EFL_INPUT_EVENT_CLICKED")
def close_requested:
  efl.eo.efl_event_lookup(
    efl.libs.elementary,
    "_EFL_UI_WIN_EVENT_DELETE_REQUEST"
  )
def click_handler:
  efl.eo.on_event(button, clicked, fun (event): efl.core.efl_exit(0))
def close_handler:
  efl.eo.on_event(window, close_requested, fun (event): efl.core.efl_exit(0))

efl.interfaces.efl_gfx_entity_visible_set(window, #true)
def exit_code = efl.core.efl_loop_begin()

efl.eo.off_event(click_handler)
efl.eo.off_event(close_handler)
efl.eo.efl_del(window)
efl.ui.elm_shutdown()
```

Set window geometry after construction. Elementary can reset geometry supplied before the window has finalized.

For a headless environment, use EFL's buffer engine when it is available:

```sh
ELM_ENGINE=buffer racket /path/to/app.rhm
```

## Using other EFL modules through Eo

### Class lookup

`efl.eo.efl_class_lookup(library, getter_name)` resolves a zero-argument C class getter and returns a tagged `Efl_Class` pointer. Initialize the relevant EFL module before using its classes.

Examples:

| Eo class | Library | Getter symbol |
| --- | --- | --- |
| `Efl.Ui.Win` | `efl.libs.elementary` | `"efl_ui_win_class_get"` |
| `Efl.Ui.Box` | `efl.libs.elementary` | `"efl_ui_box_class_get"` |
| `Efl.Ui.Button` | `efl.libs.elementary` | `"efl_ui_button_class_get"` |
| `Efl.Ui.Textbox` | `efl.libs.elementary` | `"efl_ui_textbox_class_get"` |
| `Efl.Ui.Image` | `efl.libs.elementary` | `"efl_ui_image_class_get"` |
| `Efl.Loop.Timer` | `efl.libs.ecore` | `"efl_loop_timer_class_get"` |
| `Efl.Io.Buffer` | `efl.libs.ecore` | `"efl_io_buffer_class_get"` |

Find these symbols in EFL's generated `.eo.h` headers. A C macro such as `EFL_UI_WIN_CLASS` normally maps to `efl_ui_win_class_get()`.

### Event lookup

`efl.eo.efl_event_lookup(library, symbol_name)` resolves an exported `Efl_Event_Description` variable. Event variable names normally begin with an underscore:

| Event | Library | Symbol |
| --- | --- | --- |
| Clicked | `efl.libs.evas` | `"_EFL_INPUT_EVENT_CLICKED"` |
| Window close request | `efl.libs.elementary` | `"_EFL_UI_WIN_EVENT_DELETE_REQUEST"` |
| Timer tick | `efl.libs.ecore` | `"_EFL_LOOP_TIMER_EVENT_TIMER_TICK"` |
| Object deletion | `efl.libs.eo` | `"_EFL_EVENT_DEL"` |

Do not confuse an event's C symbol with its printable name. For example, `_EFL_EVENT_DEL` has the printable name `"del"`, available as `description.name`.

### Interface support

An interface function is valid only when the target object implements that interface. For example, `Efl.Ui.Button` supports `efl_text_set`, but not `efl_text_markup_set`; use a text-capable class such as `Efl.Ui.Textbox` for markup.

When support is uncertain, look up the interface class and call `efl_isa`:

```rhombus
def markup_interface:
  efl.eo.efl_class_lookup(efl.libs.efl, "efl_text_markup_interface_get")

when efl.eo.efl_isa(object, markup_interface)
| efl.interfaces.efl_text_markup_set(object, "<b>Hello</b>")
```

Calling an unsupported Eo method can produce an EFL error and a default result rather than a Rhombus exception.

## Object construction and ownership

All constructors accept `~initialize`, a function called before Eo finalization. Use a named function for multiline initialization; Rhombus can reject a multiline lambda nested in an argument list.

| Operation | Ownership rule |
| --- | --- |
| `efl.eo.efl_add(class, parent)` | The parent owns the object's reference. Do not call `efl_unref` merely because the Rhombus wrapper is no longer needed. |
| `efl.eo.efl_add_ref(class, parent)` | The caller owns an additional reference. Balance it with `efl_unref`. A null parent is allowed with `#false`. |
| `efl.eo.efl_new(class)` | Creates an object with a null parent and one caller-owned reference. Balance it with `efl_unref`. |
| `efl.eo.efl_del(object)` | Requests deletion and detaches the object. Other references can keep it alive. |
| `efl.eo.efl_ref(object)` | Adds a reference and returns the object. |
| `efl.eo.efl_unref(object)` | Releases one reference. |
| `efl.eo.efl_ref_count(object)` | Returns the current native reference count. |

Eo and widget parenting are not the same as packing. After creating a widget with a parent, use `efl_pack_end`, `efl_pack`, or `efl_content_set` as required by the container.

Use `efl_parent_set(object, #false)` to detach an object. Ensure another reference keeps it alive when needed.

These bindings do not attach garbage-collector finalizers to Eo objects. Native ownership remains the application's responsibility.

## Events and callbacks

Use `on_event` and `off_event` instead of the raw callback functions:

```rhombus
def handler:
  efl.eo.on_event(
    object,
    description,
    fun (event): println(event.desc.name),
    ~priority: 0
  )

efl.eo.off_event(handler)
```

- The callback receives one tagged `Efl_Event` pointer with `object`, `desc`, and `info` fields.
- `event.info` is a generic pointer. Cast it to the event's documented C payload type before reading it; some events have no payload.
- `on_event` retains the Rhombus closure and its exact C callback pointer. `off_event` unregisters that pointer and releases it from the retention registry.
- Unregister handlers before destroying their target object. Destroying an object does not remove its handler from the Rhombus registry.
- Do not let a Rhombus exception escape through C. Handle errors inside the callback or communicate them back to code running outside the foreign call.
- Priorities are native `int16_t` values. EFL's conventional values are `-100` for before, `0` for default, and `100` for after.

The raw bindings `efl_event_callback_priority_add`, `efl_event_callback_del`, and `efl_event_callback_call` are also available. They expect native pointers, not the high-level handler representation.

Implementation note: EFL calls and registrations use `rhombus-ffi-lib`. Closure creation alone uses Racket's native callback API to avoid a `void_t` callback-result conversion bug in ffi2 1.1. The `PairList` in that compatibility path is intentional and required by Racket's `_cprocedure` API.

## Geometry, text, color, and containers

Construct by-value geometry types with `ffi.new`, or use `eina_rect` for a rectangle:

```rhombus
import:
  efl
  ffi

efl.interfaces.efl_gfx_entity_position_set(
  object,
  ffi.new efl.interfaces.Eina_Position2D(10, 20)
)
efl.interfaces.efl_gfx_entity_size_set(
  object,
  ffi.new efl.interfaces.Eina_Size2D(200, 100)
)
efl.interfaces.efl_gfx_entity_geometry_set(
  object,
  efl.interfaces.eina_rect(10, 20, 200, 100)
)

def geometry = efl.interfaces.efl_gfx_entity_geometry_get(object)
println([geometry.rect.x, geometry.rect.y, geometry.rect.w, geometry.rect.h])
```

`Eina_Rect` is a C union. Its `rect` variant contains `x`, `y`, `w`, and `h`; the `pos_size` and `xywh` variants expose the same storage.

Other return conventions:

- `efl_gfx_color_get(object)` returns `[r, g, b, a]` as a Rhombus list.
- String getters return Rhombus strings, or `#false` when the C string pointer is null.
- `efl_content_count` returns an unsigned integer.
- `efl_children(object)` consumes an Eina child iterator and returns a Rhombus list of Eo object pointers.
- `eina_iterator_to_list(iterator)` consumes and frees the supplied iterator.

`efl_part(object, name)` returns an Eo part proxy. As in C, the proxy is valid for one call unless it is retained with `efl_ref`.

## Null pointers and pointer identity

Rhombus pointer wrappers and Eo object identity are different things:

- A null Eo pointer returned from C can be a tagged null pointer, not `#false`.
- Test a possibly null native address with `ffi.ptr_to_uintptr(pointer) == 0`.
- Two calls that return the same Eo object can produce different Rhombus pointer wrappers. Compare native addresses rather than using `===` to test Eo identity.

```rhombus
import:
  efl
  ffi

ffi.ptr_to_uintptr(efl.eo.efl_parent_get(object)) == 0
ffi.ptr_to_uintptr(efl.eo.efl_parent_get(child)) == ffi.ptr_to_uintptr(parent)
```

Only specific wrappers, such as `efl_add_ref`, `efl_new`, and `efl_parent_set`, accept `#false` for a null Eo input. String arguments using `string_t` also accept `#false` for C `NULL`.

## API summary

### `efl.eina`

- Types: `eina_bool_t`, `Eina_Iterator`.
- Lifecycle: `eina_init`, `eina_shutdown`.
- Errors: `eina_error_get`, `eina_error_set`, `eina_error_msg_get`. Use `eina_error_set(0)` to clear the current error.
- Iterators: `eina_iterator_next`, `eina_iterator_free`, `eina_iterator_to_list`.

### `efl.eo`

- Types: `Efl_Object`, `Efl_Class`, `Efl_Event_Description`, `Efl_Event`, `EventHandler`.
- Eo lifecycle: `efl_object_init`, `efl_object_shutdown`.
- Construction: `efl_add`, `efl_add_ref`, `efl_new`.
- Ownership: `efl_del`, `efl_ref`, `efl_unref`, `efl_ref_count`.
- Hierarchy and metadata: `efl_parent_set`, `efl_parent_get`, `efl_name_set`, `efl_name_get`, `efl_comment_set`, `efl_comment_get`, `efl_debug_name_get`, `efl_children_iterator_new`, `efl_children`.
- Introspection: `efl_class_get`, `efl_class_name_get`, `efl_class_lookup`, `efl_isa`, `efl_finalized_get`, `efl_invalidated_get`, `efl_provider_find`.
- Events: `efl_event_lookup`, `on_event`, `off_event`, `efl_event_callback_priority_add`, `efl_event_callback_del`, `efl_event_callback_call`, `efl_event_callback_stop`, `efl_event_callback_count`, `efl_event_freeze`, `efl_event_thaw`, `efl_event_global_freeze`, `efl_event_global_thaw`.

### `efl.core`

- Lifecycle and loop access: `ecore_init`, `ecore_shutdown`, `efl_main_loop_get`, `efl_app_main_get`.
- Loop control: `efl_loop_begin`, `efl_loop_iterate`, `efl_loop_iterate_may_block`, `efl_exit`.
- Time and throttling: `efl_loop_time_get`, `efl_loop_throttle_set`, `efl_loop_throttle_get`.
- Timers: `efl_loop_timer_interval_set`, `efl_loop_timer_interval_get`.

`efl_loop_begin()` uses the process main loop and returns the integer supplied to `efl_exit`.

### `efl.interfaces`

- Value types: `Eina_Position2D`, `Eina_Size2D`, `Eina_Rectangle`, `Eina_Rect`, `eina_rect`.
- Parts: `efl_part`.
- Entity properties: position, size, geometry, visibility, and scale setters/getters.
- Color: `efl_gfx_color_set`, `efl_gfx_color_get`, `efl_gfx_color_code_set`, `efl_gfx_color_code_get`.
- Text: `efl_text_set`, `efl_text_get`, `efl_text_markup_set`, `efl_text_markup_get`.
- Single content: `efl_content_set`, `efl_content_get`, `efl_content_unset`.
- Packing: `efl_content_count`, `efl_pack`, `efl_pack_begin`, `efl_pack_end`, `efl_pack_at`, `efl_pack_content_get`, `efl_pack_unpack`, `efl_pack_unpack_at`, `efl_pack_clear`.
- Files: `efl_file_set`, `efl_file_get`, `efl_file_key_set`, `efl_file_key_get`, `efl_file_load`, `efl_file_unload`, `efl_file_loaded_get`.

### `efl.ui`

- `elm_init()` initializes Elementary with empty process arguments.
- `elm_shutdown()` shuts Elementary down.
- `efl_ui_win_autodel_set` and `efl_ui_win_autodel_get` control window autodel behavior.

## Extending the bindings

Keep the Eo-first scope. Do not generate a wrapper for every widget method.

1. Check the installed EFL header for the exact C signature, ownership rules, struct layout, and exporting library.
2. Prefer a class getter, event description, or an existing shared Eo interface.
3. If a genuinely essential shared operation is missing, add it in the appropriate module with its module's `foreign.linker` form and export its name.
4. Use `eina.eina_bool_t` for `Eina_Bool`, `int16_t` for callback priorities, and `string_t` for nullable UTF-8 C strings. Define structs and unions exactly as C declares them, especially for by-value calls.
5. Initialize the relevant EFL module and exercise the new call with real objects. An import or compilation check alone does not validate a C signature.
6. Update this guide when adding or changing public operations.

Do not bind C macros as though they were exported functions. In particular, object construction uses `_efl_add_internal_start` and `_efl_add_end` behind the safe Rhombus constructors because `efl_add` itself is a macro.

## Build and verification

Compile the linked package:

```sh
raco setup --pkgs rhombus-efl-lib
```

For runtime verification, use a temporary `rhombus/static` module and make real EFL calls. Cover object construction, property round-trips, callback delivery and removal, and loop exit. Use `ELM_ENGINE=buffer` for Elementary checks without a display. Remove generated `efl/compiled` artifacts from the source tree after verification when they are not wanted.

## Current limits

- There is no automatic Eo lifetime management, Eina_Value conversion, future/promise layer, or custom Eo class-definition API.
- The bindings are low-level and share the usual risks of a C FFI: invalid objects, wrong payload casts, and calls after shutdown can crash the process.
- EFL objects and the main loop should be used from EFL's main thread. Do not assume objects are safe to share across Rhombus threads.
- The API covers essential shared operations, not every Efl, Evas, Ecore, Edje, Emotion, or Elementary feature. Use the Eo lookup and interface patterns above before adding more surface area.
