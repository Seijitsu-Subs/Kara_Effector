<img width="2160" height="360" alt="Promo" src="https://github.com/user-attachments/assets/4c3ebac7-56c5-499b-91b2-7289a7d3a4a7" />

Kara_Effector 3.6.004 Seijitsu Fork
=============
Este es un fork del creador de plantillas (*templater*) [Kara Effector](https://github.com/KaraEffect0r/Kara_Effector/tree/master) para [Aegisub](https://aegisub.org/).
En este fork, se irán añadiendo las modificaciones realizadas al código original de Kara Effector 3.6 Legacy para adaptarlo a las necesidades del fansub.
Siempre que sea posible, los cambios estarán documentados para que otros grupos puedan utilizarlos si lo consideran oportuno.

Queremos extender nuestro más sincero agradecimiento a los desarrolladores originales del proyecto:
Vict8r, Karalaura, NatsuoKE e Itachi Akatsuki.

Estamos decididos a seguir innovando sobre la maravillosa base que han establecido, para que el resultado se convierta en algo aún mejor que beneficie a toda la comunidad de diseño de efectos de karaoke.

Esperamos que esto les resulte útil y que utilicen Kara Effector como un *templater* completo, y no solamente como una librería de efectos.

**Cambios incluidos hasta ahora:**
=============

## Script Principal (`Effector-3.6.004_Seijitsu.lua`)

Las modificaciones en este archivo principal se centran en mejorar la interoperabilidad con librerías externas, corregir problemas de rutas de sistema y adaptar el cálculo de resoluciones.

*   **Metadatos y Versionado:**
    *   Se actualizó el nombre del entorno a `Kara Effector Seijitsu Fork` y la versión a `3.6.004`.
    *   Se añadieron metadatos de contacto y repositorios correspondientes a Seijitsu Subs, preservando estrictamente los créditos de la autora original.
    *   Se eliminó la variable obsoleta `script_update` en el registro de macros de Aegisub para evitar redundancias.
*   **Gestión de Dependencias:**
    *   Se actualizaron las referencias de inclusión (`include`) para apuntar a las nuevas versiones del fork (`Effector-utils-lib-3.6.004_Seijitsu.lua`, `Effector-newlib-3.6.004.lua`, etc.).
    *   Se integró la carga global de una nueva librería personalizada: `ke = include( "kelibs/newkara_library.lua" )`.
*   **Implementación del "Puente de Contexto" (Context Bridge):**
    *   *Esta es la modificación estructural más importante del core.* Se introdujo un objeto `line_context` que empaqueta información crítica de la línea actual, metadatos y contadores.
    *   Se inyectaron bloques de sincronización (`ke.infofx`) dentro de los bucles de renderizado. Esto expone el estado interno del efecto (iteradores, variables del usuario, datos globales de renderizado y sílabas/caracteres activos) hacia la nueva librería externa `newkara_library`.
    *   Se reescribieron las funciones generadas dinámicamente mediante `loadstring` (utilizadas para escalar, reposicionar y re-temporizar efectos) para que ahora acepten y transmitan este nuevo objeto de contexto.
*   **Gestión de Rutas y Manejo de Errores (Autosave):**
    *   Se modificó el directorio de destino para la función de autoguardado, pasando del directorio de instalación (`?data`) al directorio de usuario (`?user`). Esto previene fallos críticos de permisos de escritura dependientes del sistema operativo.
    *   Se reformateó la concatenación de la ruta de guardado para evitar errores de sintaxis en el pathing (`%s\\autosave\\...` en lugar de `%sautosave\\...`).
    *   El mensaje de error de directorio faltante fue redactado en inglés para mayor estandarización.
*   **Cálculo de Resolución Base:**
    *   Se modificó el cálculo algorítmico del `ratio` de aspecto. El divisor base fue actualizado de `1280` a `720` (`ratio = xres / 720`), optimizando el comportamiento del script para flujos de trabajo nativos en HD.
	

## Librería de Utilidades (`Effector-utils-lib-3.6.004_Seijitsu.lua`)

Este archivo contiene el núcleo matemático y algorítmico del Kara Effector. En esta bifurcación, se han integrado parches críticos de estabilidad, optimización de velocidad de ejecución en Aegisub y mejoras en la lógica de procesamiento de strings.

*   **Metadatos y UI (Interfaz de Usuario):**
    *   Se actualizó la firma de versión a `3.6.004 Seijitsu Fork` y se añadió a *Trota* en los créditos de autoría y testeo.
    *   La interfaz gráfica (GUI) fue actualizada para reflejar los nuevos enlaces de soporte: se reemplazaron las URLs originales (Facebook/Blogspot) por el perfil de X de Seijitsu Subs, el nuevo servidor de Discord y la Wiki de Fansubhub.
    *   Se actualizaron las referencias de guardado de configuraciones hacia los nuevos archivos `.004` para no sobreescribir instalaciones originales.
*   **Parche de Optimización y Cancelación (Aegisub Progress):**
    *   Se interceptaron e inyectaron (hooking) las funciones nativas `aegisub.progress.set` y `aegisub.progress.task` dentro de `effector.run_fx`.
    *   La barra de progreso de la GUI ahora solo se actualiza cada 50 iteraciones (o al terminar). Esto reduce drásticamente el cuello de botella (overhead) generado por la comunicación entre Lua y la interfaz de Aegisub, acelerando enormemente la aplicación de macros pesadas.
    *   Se implementó soporte nativo para la cancelación por parte del usuario (`aegisub.progress.is_cancelled()`), permitiendo abortar ejecuciones largas de manera segura.
*   **Corrección Lógica de Tiempos en Palabras (Word Splitting):**
    *   Se reescribió el algoritmo de la función `text.to_word(line_text_str, line_text_dur)`.
    *   Se añadió "Detección Inteligente" de tags de karaoke. En la versión original, cadenas como `{\k10}na ni` se separaban por el espacio, rompiendo la estructura de tiempos. El nuevo algoritmo agrupa el tag de tiempo junto con la cadena de texto y sus espacios contiguos, preservando la sincronización original.
*   **Protección de Renderizado en Transformaciones (`\t`):**
    *   Se inyectó un bloque de seguridad (failsafe) dentro de la función `tag.dark`.
    *   Se fuerza la corrección automática de los tiempos en los tags `\t(t1,t2)`. Si los valores son negativos, se fuerzan a `0`. Adicionalmente, evalúa matemáticamente que `t1` nunca sea mayor a `t2` (si lo es, los iguala). Esto previene errores de sintaxis y cuelgues críticos (crashes) tanto en libass como en VSFilter al renderizar el subtítulo.
*   **Carga Modular de Extensiones:**
    *   Se integró una llamada de inclusión (`include`) al final del script para cargar dinámicamente `Effector-Seijitsu-extensions-3.6.004.lua`, estableciendo el terreno para la ejecución de *Mesh Engines* y expansiones de código personalizadas.	
	
### Para mayor claridad y modularidad, todas las funciones nuevas y personalizadas se han movido a un script separado (`Effector-Seijitsu-extensions-3.6.004.lua`). 

*   `FX_ShpOffset`
*   `FX_ShpRound`
*   `FX_ShpSimplify`
*   `FX_ShpTransform`
*   `FX_ShpBoolean`
*   `FX_ShpToCenter`
*   `FX_ShpToOrigin`
*   `FX_ShpBox`
*   `tag.create_clip_grid`
*   `color.gradient`
*   `calculate.avg_char_width`
*   `calculate.synchronized_extratime`
*   `calculate.synchronized_extratime_2`
*   `text.clean_cache`
*   `text.contorno_to_pixels`
*   `text.bord_to_pixels_v2`
*   `text.bord_to_pixels_5`
*   `shape.unite`
*   `shape.difference`
*   `shape.intersect`
*   `shape.exclude`
*   `text.to_shape_2`
*   `text.to_clip_2`
*   `color.set_2`
*   `shape.custom_clip`
*   `text.to_shape_ill`
*   `shape.borders`
*   `shape.filled_borders`
*   `shape.slice`
*   `shape.slice_grid`
*   `text.fake_zoom`
*   `shape.mesh_utils.hash_rand`
*   `shape.mesh_utils.make_circle`
*   `shape.slice_mesh`

Puede revisar el manual de esta librería en este [link](https://github.com/Seijitsu-Subs/Kara_Effector/blob/master/Docs%20and%20manuals/Kara-Effector-Seijitsu-extensions_3.6.004_Manual_ES.md).

---

### Readme_EN:

Kara_Effector 3.6.004 Seijitsu Fork
=============
This is a fork of the [Kara Effector](https://github.com/KaraEffect0r/Kara_Effector/tree/master) templater for [Aegisub](https://aegisub.org/).
In this fork, the modifications made to the original Kara Effector 3.6 Legacy code to suit the needs of the fansub will be added.
Whenever possible, the changes will be documented so that other groups may use them if they find them appropriate.

We would like to give our sincere thanks to the original developers of the project:
Vict8r, Karalaura, NatsuoKE & Itachi Akatsuki.

We are determined to keep innovating on the wonderful foundation they have laid so that the result becomes something even better that benefits the entire karaoke effects design community.

We hope this proves useful to you and that you use Kara Effector as a complete templater, not just as an effects library.

**Changes included so far:**
=============

## Main Script (`Effector-3.6.004_Seijitsu.lua`)

The modifications in this core file focus on establishing interoperability with external libraries, fixing system pathing issues, and adapting resolution calculations.

*   **Metadata and Versioning:**
    *   Updated the environment name to `Kara Effector Seijitsu Fork` and bumped the version to `3.6.004`.
    *   Added contact metadata and repository links corresponding to Seijitsu Subs while strictly preserving the original author's credits.
    *   Removed the deprecated `script_update` variable from the Aegisub macro registration lines to prevent redundancies.
*   **Dependency Management:**
    *   Updated `include` references to target the new fork versions (`Effector-utils-lib-3.6.004_Seijitsu.lua`, `Effector-newlib-3.6.004.lua`, etc.).
    *   Integrated the global inclusion of a custom library: `ke = include( "kelibs/newkara_library.lua" )`.
*   **Context Bridge Implementation:**
    *   *This is the most significant structural modification to the core.* Introduced a `line_context` object that bundles critical current-line data, metadata, and loop counters.
    *   Injected synchronization blocks (`ke.infofx`) inside the rendering loops. This safely exposes the effect's internal state (iterators, user variables, global rendering data, and active syllables/characters) to the new external `newkara_library`.
    *   Rewrote dynamically generated functions evaluated via `loadstring` (used for scaling, positioning, and retiming effects) to accept and pass forward this newly created context payload.
*   **Pathing and Error Handling (Autosave):**
    *   Migrated the target directory for the autosave feature from the installation directory (`?data`) to the user directory (`?user`). This prevents critical OS-level write-permission failures.
    *   Reformatted the save-path string concatenation to avoid pathing syntax errors (`%s\\autosave\\...` instead of `%sautosave\\...`).
    *   Standardized the missing directory error message by localizing it into English.
*   **Base Resolution Calculation:**
    *   Adjusted the algorithmic calculation for the aspect `ratio`. The base divisor was updated from `1280` to `720` (`ratio = xres / 720`), optimizing the script's behavior for native HD workflows.
	
	
## Utilities Library (`Effector-utils-lib-3.6.004_Seijitsu.lua`)

This file contains the mathematical and algorithmic core of Kara Effector. In this fork, critical stability patches, Aegisub execution speed optimizations, and improvements to the string parsing logic have been integrated.

*   **Metadata and UI (User Interface):**
    *   Updated the version signature to `3.6.004 Seijitsu Fork` and added *Trota* to the authorship and testing credits.
    *   The graphical interface (GUI) was updated to reflect new support links: original URLs (Facebook/Blogspot) were replaced with the Seijitsu Subs X/Twitter profile, the new Discord server, and the Fansubhub Wiki.
    *   Updated save-configuration references to target the new `.004` files, preventing the overriding of original KE installations.
*   **Optimization and Cancellation Patch (Aegisub Progress):**
    *   Intercepted and hooked the native `aegisub.progress.set` and `aegisub.progress.task` functions inside `effector.run_fx`.
    *   The GUI progress bar now only updates every 50 iterations (or at completion). This drastically reduces the overhead generated by Lua-to-GUI communication, vastly speeding up the execution of heavy macros.
    *   Implemented native user-cancellation support (`aegisub.progress.is_cancelled()`), safely allowing the abortion of long-running executions.
*   **Word Splitting Timing Fix:**
    *   Completely rewrote the `text.to_word(line_text_str, line_text_dur)` function algorithm.
    *   Added "Smart Detection" for karaoke tags. In the legacy version, strings with spaces like `{\k10}na ni` were split at the space, destroying the timing structure. The new algorithm bundles the timing tag along with the text and its trailing spaces, flawlessly preserving the original sync.
*   **Renderer Protection for Transforms (`\t`):**
    *   Injected a mathematical failsafe block inside the `tag.dark` function.
    *   It forces automatic time correction for `\t(t1,t2)` tags. If the values are negative, they are clamped to `0`. Additionally, it ensures that `t1` is never greater than `t2` (if it is, they are equated). This prevents syntax errors and critical crashes in both libass and VSFilter during subtitle rendering.
*   **Modular Extension Loading:**
    *   Added an `include` call at the end of the script to dynamically load `Effector-Seijitsu-extensions-3.6.004.lua`, laying the groundwork for *Mesh Engines* and custom code expansions.
	
	
### For greater clarity and modularity, all new and custom functions have been moved to a separate script (`Effector-Seijitsu-extensions-3.6.004.lua`).

*   `FX_ShpOffset`
*   `FX_ShpRound`
*   `FX_ShpSimplify`
*   `FX_ShpTransform`
*   `FX_ShpBoolean`
*   `FX_ShpToCenter`
*   `FX_ShpToOrigin`
*   `FX_ShpBox`
*   `tag.create_clip_grid`
*   `color.gradient`
*   `calculate.avg_char_width`
*   `calculate.synchronized_extratime`
*   `calculate.synchronized_extratime_2`
*   `text.clean_cache`
*   `text.contorno_to_pixels`
*   `text.bord_to_pixels_v2`
*   `text.bord_to_pixels_5`
*   `shape.unite`
*   `shape.difference`
*   `shape.intersect`
*   `shape.exclude`
*   `text.to_shape_2`
*   `text.to_clip_2`
*   `color.set_2`
*   `shape.custom_clip`
*   `text.to_shape_ill`
*   `shape.borders`
*   `shape.filled_borders`
*   `shape.slice`
*   `shape.slice_grid`
*   `text.fake_zoom`
*   `shape.mesh_utils.hash_rand`
*   `shape.mesh_utils.make_circle`
*   `shape.slice_mesh`

You can check the docs for this library using this [link](https://github.com/Seijitsu-Subs/Kara_Effector/blob/master/Docs%20and%20manuals/Kara-Effector-Seijitsu-extensions_3.6.004_Manual_EN.md).

---

