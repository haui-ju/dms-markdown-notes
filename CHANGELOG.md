# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). El proyecto usa [versionado semántico](https://semver.org/lang/es/).

## [Sin publicar]

### Añadido

- Las citas se ven con una barra de color y un fondo suave, también cuando están vacías.
- Enter al final de una cita añade otro párrafo a la cita; Enter en uno vacío sale de ella.
- Más espacio encima y debajo de tablas e imágenes.

### Corregido

- Una cita vacía (recién creada o tras borrar su texto) desaparecía al guardar.
- La vista Markdown sin formato mostraba todo el texto con el tamaño de un título (o en fuente de código) según dónde estaba el cursor al cambiar de vista.

- Los bloques de código no funcionaban (sin fondo, botones ni teclas propias) en notas con una tabla, una imagen o un separador antes del bloque.
- Un separador justo encima de un bloque de código desaparecía al guardar.

## [0.5.0] - 2026-09-29

### Añadido

- Las propiedades YAML (front matter) al inicio de una nota se conservan y quedan ocultas en la vista formateada.
- Las pestañas con el mismo nombre en carpetas distintas muestran también la carpeta.
- Aviso cuando se intenta renombrar una nota con un nombre que ya existe.
- Script `pnpm release`, CHANGELOG y ficha para el registro de plugins de DMS.

### Corregido

- Renombrar una pestaña y cambiar a otra antes de confirmar renombraba la segunda con el nombre de la primera.
- Renombrados seguidos se perdían y un renombrado podía actualizar la pestaña equivocada si se cerraba otra mientras tanto.
- Los enlaces a imágenes de una nota que no está abierta ahora se corrigen al renombrarla.
- Al escribir tras `# ` (o Ctrl+1/2/3 en una línea vacía) el texto ya se ve como título, sin esperar a Enter.
- El primer carácter de un párrafo nuevo ya no se deshace por separado.
- Borrar el texto de un título convertía en título el bloque de debajo al guardar (error del serializador de Qt). Los títulos vacíos se guardan ahora como `# ` + NBSP y siguen formateándose al escribir.

## [0.4.1] - 2026-09-29

### Corregido

- Ctrl+Z, Ctrl+Y y Ctrl+Shift+Z funcionan tras autoformatos, tablas, bloques de código, pegados e imágenes, con historial por pestaña.

## [0.4.0] - 2026-09-29

### Añadido

- Imágenes: pegar con Ctrl+V o `/imagen`, guardadas en una carpeta junto a la nota, y visor flotante al hacer clic.

## [0.3.0] - 2026-09-29

### Añadido

- Bloques de código con resaltado de sintaxis, selector de lenguaje, copiar y eliminar.
- Pegado limpio desde webs, documentos y editores de código.

## [0.2.0] - 2026-09-29

### Añadido

- Menú `/` de bloques y tablas editables con anchos, ancho completo, igualar columnas y densidad.

## [0.1.0] - 2026-09-29

### Añadido

- Primera versión: panel lateral con pestañas, ventana flotante, formato Markdown mientras escribes, listas, checklists y guardado automático en `~/Notes`.

[0.5.0]: https://github.com/haui-ju/dms-markdown-notes/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/haui-ju/dms-markdown-notes/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/haui-ju/dms-markdown-notes/releases/tag/v0.4.0
