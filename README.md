Kara_Effector 3.6 Seijitsu Fork
=============
In this fork, the modifications made to the original Kara Effector 3.6 Legacy code to suit the needs of the fansub will be added.
Whenever possible, the changes will be documented so that other groups may use them if they find them appropriate.

I hope this proves useful to you and that you use Kara Effector as a complete templater, not just as an effects library.

**Changes included so far:**
=============

> **Effector-3.6.lua replaced by Effector-3.6\_Seijitsu.lua:**

* The original Lua file has been replaced with a modified version so both can coexist in Aegisub at the same time.

* A table has been added to the line `local line_context` to provide context to `calculate.extratime( )`.

> **Effector-utils-lib-3.6.lua:**

* Many descriptive UI windows with tips and hints have been removed for sheer convenience.

* The section intended to prevent the name change of Effector-3.6.lua has been commented out.

> **Effector-newfx-3.6.lua:**

* No changes for now. This is where we’ll add the effects we want to share with the community.

> **Effector-newlib-3.6.lua:**

* Added new function: `tag.create_clip_grid(current_index, cols, rows, box, mode, is_inverse)`

**Custom clip function to generate clip grids independently of `maxloop( )`.**

* Added new function: `color.gradient( pct, ... )`

**Function that allows interpolating more than two colors at the same time.**

* Added new function:
  `calculate.extratime(ctx, progression_per_char, fade_duration, start_delay, end_delay, desired_gap, max_added_time)`

**Function that calculates the time window between the current line and the next to add it to the delay intended for the exit animation. It’s used to achieve a perfect transition between effect lines.**

---

