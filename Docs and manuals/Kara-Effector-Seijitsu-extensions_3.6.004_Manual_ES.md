### 🇪🇸 Versión en Español: Manual de Extensiones Seijitsu

## Referencia Técnica de Funciones (`Effector-Seijitsu-extensions-3.6.004.lua`)

### Transformaciones y Operaciones Base (Suite ILL)

#### `FX_ShpOffset`
```lua
FX_ShpOffset(str: string, dist: number) -> string
```
*   **Descripción Técnica:** Realiza un desplazamiento (offset) algorítmico sobre los vértices de un trazado vectorial ASSDraw. No escala la forma matemáticamente, sino que expande (infla) o contrae (desinfla) el contorno perpendicularmente a lo largo de todas sus aristas utilizando la librería Clipper. Finaliza con un paso de auto-simplificación (`p:simplify(0.5)`) para limpiar vértices colineales.
*   **Argumentos:**
    *   `str`: Código vectorial en formato ASSDraw. Si contiene valores corruptos (`nan` o `inf`), la función los sanitiza internamente.
    *   `dist`: Magnitud del desplazamiento. Valores positivos expanden la geometría; valores negativos la contraen hacia el baricentro. (Por defecto: `0.0`).
*   **Comportamiento Avanzado:**
    *   **Join Type:** Forzado a usar el método "round". Al expandir esquinas muy agudas (como la punta de una estrella), curvará las esquinas para mantener la geometría suave, evitando picos extendidos al infinito (Miter join).
    *   **Seguridad:** Encapsulada en un `pcall`. Si la topología es un polígono auto-intersectante irresoluble, devolverá el string original sin generar un *crash* fatal en Aegisub.

#### `FX_ShpRound`
```lua
FX_ShpRound(str: string, rad: number) -> string
```
*   **Descripción Técnica:** Aplica un suavizado de vértices (fillet/round) a una topología vectorial. Transforma las esquinas agudas formadas por líneas rectas (`l`) en curvas de Bézier cúbicas (`b`), basándose en un radio de curvatura absoluto.
*   **Comportamiento Avanzado:** Utiliza el método `Absolute` de la clase `RoundingPath` de ILL, asegurando dimensiones consistentes. Si el radio es mayor a la longitud de los segmentos, calcula el límite máximo posible de curvatura para evitar que los vectores se sobrepongan. Si el motor C++ falla, realiza un *bypass* retornando el string intacto.

#### `FX_ShpBoolean`
```lua
FX_ShpBoolean(str_A: string, str_B: string, op: string) -> string
```
*   **Descripción Técnica:** Procesador central de operaciones CSG (Constructive Solid Geometry). Mantiene los agujeros apropiadamente enmascarados según la regla "EvenOdd".
*   **Modos de Operación (`op`):**
    *   `"union"` o `"unite"`: Fusiona ambas formas eliminando contornos internos superpuestos.
    *   `"difference"`: Sustrae el área de `str_B` de la geometría de `str_A`.
    *   `"xor"` o `"exclude"`: Crea vacíos exactos donde ambas formas se superponen.
    *   `"intersect"`: Retorna exclusivamente la región donde colisionan (área compartida).
*   **Post-procesado:** Invoca una simplificación agresiva post-cálculo para minimizar el peso del texto de salida final (reducción de lag).

#### Transformaciones Espaciales (`FX_ShpTransform`, `FX_ShpToCenter`, `FX_ShpToOrigin`)
```lua
FX_ShpTransform(str: string, sx: number, sy: number, rot: number, tx: number, ty: number) -> string
FX_ShpToCenter(str: string) -> string
FX_ShpToOrigin(str: string) -> string
```
*   **Descripción Técnica:** Aplican transformaciones afines directamente sobre los vértices en la memoria de ILL, sin usar los tags nativos de ASS.
*   **Orden Matricial (`FX_ShpTransform`):** Escala ➔ Rotación ➔ Traslación. Posee optimización por *bypass* (omite el cálculo si un parámetro es neutro o nil).
*   **Centrado y Origen:** `FX_ShpToCenter` devuelve la forma centrada perfectamente en `(0,0)`. `FX_ShpToOrigin` desplaza la forma para que su esquina Top-Left encaje en `(0,0)`.

#### `FX_ShpBox`
```lua
FX_ShpBox(str: string) -> table {x, y, w, h, cx, cy}
```
*   **Descripción Técnica:** Calcula y extrae la AABB (Axis-Aligned Bounding Box). Retorna una tabla estructurada lista para ser consumida por los motores de malla.
*   **Seguridad Estricta:** Implementa un failsafe que retorna una caja en ceros en lugar de `nil` si el string es inválido, evitando colapsos por división por cero en funciones algorítmicas anidadas.

---

### Generación, Análisis y Tiempos

#### `tag.create_clip_grid`
*   **Descripción:** Divide un área rectangular en una cuadrícula virtual y devuelve el tag `\clip` o `\iclip` de la celda solicitada.
*   **Comportamiento Avanzado:** Es una función sin estado (*stateless*). Utiliza álgebra de módulos para invertir coordenadas y crear barridos direccionales puros. Permite sangrado (overlap) escalar o matricial (`{x, y}`) para evitar "costuras" visibles entre celdas.

#### `color.gradient`
*   **Descripción:** Interpolador multi-escala. Traduce un escalar de 0 a 1 (`pct`) en una posición dentro de un arreglo infinito de colores, calculando la mezcla exacta en ese sub-segmento. Gestiona el desbordamiento encapsulando los valores forzosamente.

#### `calculate.avg_char_width`
*   **Descripción:** Escaneo topológico de un string para extraer el promedio aritmético de ancho por carácter, excluyendo explícitamente los espacios en blanco, ya que sus métricas inconsistentes sesgan la media matemática de las letras.

#### `calculate.synchronized_extratime` (y variante `_2`)
*   **Descripción:** Motor algorítmico *Lookahead*. Analiza líneas futuras para calcular los milisegundos exactos necesarios para que la animación de salida enganche con la de entrada de la línea siguiente.
*   **Lógica Espacio-Temporal:** Cuenta la densidad de caracteres (P2), calcula el salto espacial (traduce píxeles de distancia entre palabras a milisegundos) y encierra el resultado en un cálculo restrictivo para jamás devolver tiempos negativos. La versión `_2` incluye umbrales máximos de retraso (threshold) para cortar la sincronización en cambios de escena.

---

### Motores de Vectorización y Píxeles (Suite `ke`)

#### `text.to_shape_ill`
*   **Descripción:** "Wrapper Supremo" de conversión. Convierte texto a vector leyendo las propiedades de Aegisub. 
*   **Caché Criptográfico:** Si una sílaba y sus propiedades ya fueron renderizadas, extrae el string de la RAM usando un hash único (ej. `shp_ill_v1_hola_sc1.00...`), reduciendo tiempos de carga en un 80%. Aplica un auto-centrado geométrico para alinear el vector al eje de la línea de pantalla.

#### `text.contorno_to_pixels`
*   **Descripción:** Generador de partículas que ignora los huecos internos de la tipografía (ej. el centro de la "O"). Utiliza cálculos AABB para clasificar los trazados, descartando aquellos que son "agujeros". Finaliza con una *Criba Cuadrática* (Point Culling) para desechar partículas acumuladas innecesariamente.

#### `text.bord_to_pixels_v2` (y `_5`)
*   **Descripción:** Fuerza un remuestreo isométrico estricto usando C++. Transforma las curvas de Bézier en líneas rectas perfectas antes de extraer vértices. 
*   **Comportamiento:** Posee un control de cierre (Closure) que evita partículas superpuestas si el trazado da la vuelta completa. *Aviso:* Esta función secuestra el iterador `maxloop` del Kara Effector.

---

### Operadores Booleanos de Arreglo
```lua
shape.[unite / difference / intersect / exclude](... : string | table) -> string
```
*   **Descripción:** Procesan secuencias de formas y aplican operaciones de Geometría Sólida Constructiva iterativa y acumulativamente.
*   **Comportamiento:** Toman el primer elemento como base y aplican el operador contra el siguiente en un bucle `for`. Poseen tolerancia a fallos silenciosa (Failsafe) omitiendo índices corruptos.

#### `shape.custom_clip`
*   **Descripción:** Rompe la limitación nativa de Aegisub de un solo `\clip`, usando cualquier forma como máscara destructiva sobre otra. Fuerza la regla de polígonos `EvenOdd` para respetar los agujeros de máscaras complejas.

#### `shape.borders` y `shape.filled_borders`
*   **Descripción:** Generan expansiones perimetrales concéntricas mediante doble offset booleano (Offset Exterior - Offset Interior).
*   **Caché Iterativo:** Calcula todos los anillos solicitados en el bucle `j=1` y los almacena en RAM. En bucles posteriores, solo los extrae, permitiendo grosores variables dinámicos mediante tablas (`{5, 10, 2}`).

---

### Arquitectura del Mesh Engine (Orquestador y Cortadores)

La arquitectura del fork se sostiene sobre dos motores simbiontes:
1.  **Suite `ke` (newkara_library):** Motor de "Nivel Superior". Rasterización tipográfica y gestión de estilos.
2.  **Suite ILL Directa (Prefijos `FX_`):** Motor de "Nivel Inferior". Manipulación geométrica masiva en RAM, ideal para recalcular miles de polígonos por segundo.

#### La Familia Slice (`shape.slice`, `shape.slice_grid`)
Son cortadores lineales. `slice` realiza cortes paralelos con rotación trigonométrica inversa y aceleración (`Accel`). `slice_grid` proyecta matrices NxM. Ambas admiten un Modo "clip" que devuelve las coordenadas de las cuchillas invisibles.

#### El Orquestador: `shape.slice_mesh`
```lua
shape.slice_mesh(Shape_or_Text, Mode, Size, Overlap, Separation, Scale) -> string
```
Administrador central del sistema. Su ciclo de vida es:
1.  **Preparación:** Obtiene el vector base (`text.to_shape_ill`).
2.  **Cálculo:** Genera la llave caché y el Bounding Box (`FX_ShpBox`).
3.  **Delegación:** Envía la información al Motor de Malla correspondiente.
4.  **Culling y Booleanos:** Descarta piezas inútiles y aplica intersecciones y solapamientos.
5.  **Secuestro:** Ajusta el `maxloop` a las piezas resultantes.

#### Catálogo de Motores de Malla (`shape.mesh_engines`)
*(El argumento `Size` es polimórfico y muta a una matriz `cfg` según el motor seleccionado).*

*   **Grupo 1: Geometría Monolítica (1 Parámetro: Radio):**
    *   `hex`, `tri`, `dia`, `rhombille` (Cubos Q*bert), `octagon` (Mosaico Arquimediano), `kagome` (Estrella de David), `truchet` (Tuberías curvas).
*   **Grupo 2: Arquitectónicos (Tabla de múltiples parámetros):**
    *   `brick` (Ladrillos), `ashlar` (Piedra rústica horizontal 1D), `herringbone` (Punto de espiga/Zig-Zag), `scallop` (Escamas rotables).
*   **Grupo 3: Radiales (Coordenadas polares):**
    *   `ray`, `ring`, `web` (Telaraña / Vidrio Roto con nivel de caos y epicentro personalizable).
*   **Grupo 4: División Irregular (Glitch procedural):**
    *   `mondrian` (Rectángulos asimétricos), `quad` (Subdivisión cuadrada estricta).
*   **Grupo 5: Motores Ultra-Avanzados:**
    *   `circuit` (Placa Base). Aplica lógica booleana negativa: devuelve los agujeros transparentes del circuito grabado, incluyendo pads de soldadura procedurales.
    *   `pattern`. Orquestador de clonación. Permite instanciar figuras externas (ej. `shape.heart`), intercalarlas en matriz y aplicarlas como malla de corte o como perforación en el texto.

**Ejemplo de Uso Práctico:**
```lua
Variables[fx]:
forma_custom = "m 0 0 l 50 100 l 100 0 l 0 0"; -- Triángulo invertido
config = { forma_custom, 30, 25, true, false };

mesh = shape.slice_mesh( syl.text, "pattern", config, 0, 10 );
```
*Efecto resultante:* La sílaba estalla en bloques cuadrados desfasados (muro), cada uno con un triángulo transparente perforado en su interior, calculado en milisegundos mediante caché determinístico.

### Uso Avanzado del Argumento `Size` (`cfg`) en `shape.slice_mesh`

En la función `shape.slice_mesh`, el tercer parámetro (oficialmente llamado `Size`) es **polimórfico**. Internamente, el orquestador lo transforma en una tabla de configuración (`cfg`). La forma en la que debes escribir este parámetro cambia drásticamente dependiendo del motor (`Mode`) que hayas seleccionado.

A continuación, se detalla cómo estructurar este argumento según la familia del motor:

#### > Motores Monolíticos (Un solo valor)
Para formas geométricas regulares y radiales simples, el argumento funciona simplemente como el **Radio** o **Tamaño Base** de la celda. Puedes pasar un número directo o una tabla con un solo valor.
*   **Motores:** `"hex"`, `"tri"`, `"dia"`, `"rhombille"`, `"octagon"`, `"kagome"`, `"truchet"`, `"ray"`, `"ring"`.
*   **Sintaxis:** `20` o `{20}` *(Ej: Hexágonos de 20px de radio).*

#### > Motores Arquitectónicos y Vectoriales (Múltiples parámetros)
Estos motores requieren dimensiones específicas (X e Y) o modificadores adicionales, por lo que **debes** pasar una tabla ordenada.
*   **`"brick"`** ➔ `{ Ancho, Alto, Ratio_Desfase }` (Ej: `{30, 15, 0.5}`)
*   **`"ashlar"`** ➔ `{ Ancho_Minimo, Ancho_Maximo, Alto_Fila }` (Ej: `{10, 40, 15}`)
*   **`"herringbone"`** ➔ `{ Longitud_Ladrillo, Grosor_Ladrillo }` (Ej: `{30, 10}`)
*   **`"scallop"`** ➔ `{ Radio, Angulo_Rotacion }` (Ej: `{15, 180}` *para escamas invertidas*)

#### > Motores Radiales y de Impacto
*   **`"web"`** ➔ `{ Num_Anillos, Num_Rayos, Nivel_Caos, CentroX (opcional), CentroY (opcional) }` 
    *(Ej: `{5, 12, 0.3}` genera una telaraña de 5 anillos y 12 puntas con un 30% de distorsión orgánica).*

#### > Motores de Glitch y Subdivisión
*   **`"mondrian"`** ➔ `{ Tamaño_Minimo, Probabilidad_Corte }` (Ej: `{12, 0.45}`)
*   **`"quad"`** ➔ `{ Tamaño_Minimo, prob = 0.5 }` 
    *(⚠️ **Aviso crítico:** En el motor quad, la probabilidad debe declararse con la llave explícita `prob=`).*

#### > Motores Ultra-Avanzados
*   **`"circuit"`** ➔ `{ Tamaño_Celda, Grosor_Pista, Probabilidad_Soldadura }` (Ej: `{20, 3, 0.2}`)
*   **`"pattern"`** ➔ `{ Forma_String, Tamaño_Celda, Tamaño_Dibujo, Intercalar_Filas_Bool, Es_Positivo_Bool }` 
    *(Ej: `{ shape.star, 30, 20, true, false }` perfora el texto con estrellas intercaladas).*
