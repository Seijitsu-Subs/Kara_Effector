### 🇬🇧 English Version: Seijitsu Extensions Manual

## Technical Reference (`Effector-Seijitsu-extensions-3.6.004.lua`)

### Transformations and Base Operations (ILL Suite)

#### `FX_ShpOffset`
```lua
FX_ShpOffset(str: string, dist: number) -> string
```
*   **Technical Description:** Performs an algorithmic offset on the vertices of an ASSDraw vector path. Instead of mathematically scaling the shape, it expands (inflates) or contracts (deflates) the contour perpendicularly along all edges using the Clipper library. It concludes with a self-simplification step (`p:simplify(0.5)`) to clean up collinear vertices.
*   **Arguments:**
    *   `str`: Vector code in ASSDraw format. Internal sanitation handles corrupt values (`nan` or `inf`).
    *   `dist`: Offset magnitude. Positive values expand outward; negative values contract inward. (Default: `0.0`).
*   **Advanced Behavior:**
    *   **Join Type:** Internally forced to use the "round" method. When expanding extremely sharp corners (like a star point), it curves them to keep the geometry contained and smooth instead of generating infinite spikes (Miter join).
    *   **Failsafe:** Encapsulated in a `pcall`. If the topology is an unsolvable self-intersecting polygon, it returns the original string without triggering a fatal crash in Aegisub.

#### `FX_ShpRound`
```lua
FX_ShpRound(str: string, rad: number) -> string
```
*   **Technical Description:** Applies a fillet/round smoothing to a vector topology. It transforms sharp corners formed by straight lines (`l`) into cubic Bézier curves (`b`), based on an absolute curvature radius.
*   **Advanced Behavior:** Uses the `Absolute` method from ILL's `RoundingPath` class, ensuring consistent dimensions regardless of segment length. If the radius exceeds the available segment length, the library caps it to prevent vector overlapping. If the C++ engine fails to initialize, it performs a bypass, returning the untouched string.

#### `FX_ShpBoolean`
```lua
FX_ShpBoolean(str_A: string, str_B: string, op: string) -> string
```
*   **Technical Description:** Core processor for CSG (Constructive Solid Geometry) operations. Returns curves accurately masked according to the "EvenOdd" fill rule.
*   **Operation Modes (`op`):**
    *   `"union"` or `"unite"`: Merges both shapes, removing overlapping internal contours.
    *   `"difference"`: Subtracts `str_B`'s area from `str_A`.
    *   `"xor"` or `"exclude"`: Retains the combined area but creates precise voids where both shapes overlap.
    *   `"intersect"`: Returns exclusively the collision region (shared area).
*   **Post-processing:** Invokes aggressive simplification immediately after resolving the topology to minimize final payload weight and reduce rendering lag.

#### Spatial Transforms (`FX_ShpTransform`, `FX_ShpToCenter`, `FX_ShpToOrigin`)
```lua
FX_ShpTransform(str: string, sx: number, sy: number, rot: number, tx: number, ty: number) -> string
FX_ShpToCenter(str: string) -> string
FX_ShpToOrigin(str: string) -> string
```
*   **Technical Description:** Applies affine transformations directly to the vertices in ILL memory, bypassing native ASS tags.
*   **Matrix Execution Order (`FX_ShpTransform`):** Scale ➔ Rotation ➔ Translation. Features a bypass optimization (skipping calculations if parameters are neutral or nil).
*   **Centering and Origin:** `FX_ShpToCenter` recalculates vertices to center the shape perfectly at `(0,0)`. `FX_ShpToOrigin` shifts the geometry so its Top-Left bounding corner snaps to `(0,0)`.

#### `FX_ShpBox`
```lua
FX_ShpBox(str: string) -> table {x, y, w, h, cx, cy}
```
*   **Technical Description:** Calculates and extracts the AABB (Axis-Aligned Bounding Box) of a vector topology. Returns a pre-structured data table ready for Mesh Engines consumption.
*   **Strict Failsafe:** If the input string is invalid, it intercepts the crash and returns a zeroed-out box instead of `nil`. This critical shield prevents nested algorithmic engines from collapsing due to zero-division errors.

---

### Generation, Analysis, and Timing

#### `tag.create_clip_grid`
*   **Description:** Partitions a rectangular area into a virtual grid, returning the `\clip` or `\iclip` tag for the requested cell.
*   **Advanced Behavior:** A stateless function. Uses modulo algebra to invert coordinates dynamically, enabling pure directional sweeps. Supports scalar or matrix (`{x, y}`) bleed/overlap to prevent visible "seams" between rotated cells.

#### `color.gradient`
*   **Description:** Multi-stop color interpolator. Maps a `0.0` to `1.0` scalar (`pct`) across an infinite array of color nodes. Handles overflow by strictly clamping values to prevent nil index errors.

#### `calculate.avg_char_width`
*   **Description:** Scans string topology to extract the arithmetic average width per character. Explicitly excludes whitespaces, whose inconsistent metrics heavily skew true font measurements.

#### `calculate.synchronized_extratime` (and `_2` variant)
*   **Description:** Highly advanced Lookahead predictive engine. Calculates the exact milliseconds required to seamlessly chain the current line's exit animation with the incoming animation of the next dialogue line.
*   **Spatio-Temporal Logic:** Analyzes future density (P2), computes spatial jumps (translating pixel distance between words into milliseconds), and clamps the final result to guarantee non-negative durations. The `_2` variant includes threshold caps to sever synchronization during long scene cuts.

---

### Vectorization and Pixel Engines (`ke` Suite)

#### `text.to_shape_ill`
*   **Description:** The "Ultimate Wrapper" for text-to-vector conversion. Reads Aegisub's typographic properties and generates vector code via C++.
*   **Cryptographic Cache (Hash):** If a syllable and its exact properties were rendered previously, it pulls the geometry straight from RAM using a unique hash (e.g., `shp_ill_v1_hola...`), slashing render times by 80%. Implements geometric auto-centering to align the mathematical vector origin with the screen line axis.

#### `text.contorno_to_pixels`
*   **Description:** Particle generator that ignores inner typography voids (e.g., the inside of an "O"). Uses AABB logic to classify paths, discarding internal "holes." Finishes with a Quadratic Culling pass (Point Culling) to discard excessively clustered particles.

#### `text.bord_to_pixels_v2` (and `_5` alias)
*   **Description:** Forces strict isometric resampling via C++. Transforms Bézier curves into tiny, mathematically perfect straight lines before extracting vertices.
*   **Behavior:** Features a Closure control block that prevents vertex overlapping when closed perimeters complete their loop. *Warning:* This function hijacks Kara Effector's global `maxloop` iterator.

---

### Boolean Array Operators
```lua
shape.[unite / difference / intersect / exclude](... : string | table) -> string
```
*   **Description:** Processes sequences of vector shapes and applies CSG operations iteratively and cumulatively.
*   **Behavior:** Uses the first valid string as the base and applies the operator against the next element in a `for` loop. Features silent failsafes, bypassing corrupt indices without crashing the execution.

#### `shape.custom_clip`
*   **Description:** Shatters Aegisub's native one-clip limitation by allowing any arbitrary shape to act as a destructive mask over another shape. Forces the `EvenOdd` fill rule to respect internal voids in complex masks.

#### `shape.borders` and `shape.filled_borders`
*   **Description:** Concentric topographic generators. Creates perimeter outlines via dual-offset boolean subtraction (Outer Offset - Inner Offset).
*   **Iterative Cache:** Calculates all requested rings during the `j=1` loop and stores them in RAM. Subsequent loops merely fetch the strings, enabling dynamic thicknesses via tables (e.g., `{5, 10, 2}`).

---

### Mesh Engine Architecture (Orchestrator and Cutters)

The fork's architecture relies on two symbiotic engines:
1.  **`ke` Suite (newkara_library):** "High-level" engine. Handles typographic rasterization and style parsing.
2.  **ILL Direct Suite (`FX_` prefixes):** "Low-level" engine. Handles extreme geometric manipulation directly in RAM, processing thousands of polygons per second.

#### The Slice Family (`shape.slice`, `shape.slice_grid`)
Linear cutters. `slice` executes parallel cuts using inverse sine/cosine trigonometry and acceleration (`Accel`). `slice_grid` projects NxM matrices. Both support a "clip" Mode that outputs invisible blade coordinates to bypass native ASS anti-aliasing artifacts.

#### The Orchestrator: `shape.slice_mesh`
```lua
shape.slice_mesh(Shape_or_Text, Mode, Size, Overlap, Separation, Scale) -> string
```
The central manager. Its lifecycle is:
1.  **Preparation:** Retrieves the base vector (`text.to_shape_ill`).
2.  **Calculation:** Generates the cache key and extracts the Bounding Box (`FX_ShpBox`).
3.  **Delegation:** Dispatches data to the specified Mesh Engine.
4.  **Culling & Booleans:** Discards out-of-bounds pieces and applies overlaps and intersections.
5.  **Hijacking:** Adjusts `maxloop` to match the exact valid piece count.

#### Mesh Engines Catalog (`shape.mesh_engines`)
*(The `Size` argument is polymorphic and mutates into a `cfg` configuration table based on the selected engine).*

*   **Group 1: Monolithic Geometry (1 Parameter: Radius):**
    *   `hex` / `honeycomb`, `tri` / `triangle`, `dia` / `diamond`, `rhombille` (Q*bert cubes), `octagon` (Archimedean Tessellation), `kagome` (Star of David), `truchet` (Curved pipes).
*   **Group 2: Architectural (Multi-parameter table):**
    *   `brick` (Standard wall), `ashlar` (1D rustic stone), `herringbone` (Zig-zag pattern), `scallop` (Rotatable mermaid scales).
*   **Group 3: Radial (Polar coordinates):**
    *   `ray` / `radial`, `ring` / `circle`, `web` (Shattered glass/Spiderweb with customizable chaos and epicenter).
*   **Group 4: Irregular Division (Procedural Glitch):**
    *   `mondrian` (Asymmetric rectangles), `quadtree` / `quad` (Strict recursive square subdivision).
*   **Group 5: Ultra-Advanced Engines:**
    *   `circuit` (Tech Board). Employs negative boolean logic to return the voids of an etched circuit board, complete with procedural solder pads.
    *   `pattern`. Cloning Orchestrator. Instantiates external shapes (e.g., `shape.heart`), arrays them into a staggered matrix, and applies them as either a positive cutout mesh or negative text perforations.

**Practical Workflow Example:**
```lua
Variables[fx]:
custom_shape = "m 0 0 l 50 100 l 100 0 l 0 0"; -- Inverted triangle
config = { custom_shape, 30, 25, true, false };

mesh = shape.slice_mesh( syl.text, "pattern", config, 0, 10 );
```
*Resulting Effect:* The syllable shatters into staggered square blocks (brick wall), each pierced with a transparent inverted triangle hole, rendered in milliseconds thanks to deterministic hashing.