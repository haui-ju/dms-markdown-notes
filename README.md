# dms-markdown-notes

Plugin para [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) que añade un panel lateral de notas Markdown estilo Notion: el formato se ve mientras escribes y cada nota es un archivo `.md` normal en `~/Notes`.

## Instalación

```bash
git clone https://github.com/haui-ju/dms-markdown-notes.git
cd dms-markdown-notes
./install.sh
```

`install.sh` enlaza el repo en `~/.config/DankMaterialShell/plugins/markdownNotes`, crea `~/Notes`, activa el plugin y añade el botón a la barra (reinicia `dms.service` si está corriendo).

Atajo global opcional en Hyprland:

```ini
bind = SUPER, N, exec, dms ipc call markdownNotes toggle
```

Comandos IPC: `toggle`, `open`, `close`, `newNote`, `popout` (ventana flotante), `dock` (volver al panel lateral).

## Interfaz

Igual que el Notepad de DMS: pestañas de notas abiertas (× cierra la pestaña sin borrar el archivo, doble clic renombra, + crea), botón para ampliar/contraer el panel, **Guardar** (en notas sin nombre abre "Guardar como"), **Abrir** (cualquier `.md`), **Nuevo**, ventana flotante, menú `…` (ver Markdown, renombrar, abrir carpeta, mover a la papelera) y barra de estado con caracteres, líneas, estado de guardado y ruta del archivo (ⓘ). Las pestañas abiertas se recuerdan entre sesiones.

## Escritura

| Escribes | Resultado |
| --- | --- |
| `# `, `## `, `### ` | Título H1, H2, H3 |
| `- ` o `* ` | Lista con viñetas |
| `1. ` | Lista numerada |
| `[] ` o `- [] ` | Checkbox (clic en la casilla para marcarla) |
| `> ` | Cita |
| `---` + Enter | Separador |
| ```` ``` ```` + Enter | Bloque de código |
| `**texto**`, `*texto*`, `` `texto` ``, `~~texto~~` | Negrita, cursiva, código, tachado |
| Enter en un elemento vacío | Termina la lista |
| Enter al final de un título | La línea siguiente es texto normal |
| Retroceso al inicio de un título, cita o lista | Vuelve a texto normal |

## Menú `/`

Escribe `/` al inicio de una línea (o después de un espacio) para abrir el menú de bloques, como en Notion. Lo que escribas después filtra la lista sin importar tildes (`/tab`, `/titulo`, `/tareas`). Flechas para moverte, Enter o Tab para aplicar, Esc para cerrar.

Bloques: Texto, Título 1-3, Lista, Lista numerada, Lista de tareas, Cita, Separador, Bloque de código y **Tabla**.

## Tablas

- `/tabla` crea una tabla de 3×3 (encabezado + 2 filas) con "Columna 1" seleccionado para que empieces a escribir.
- **Tab** / **Shift+Tab**: celda siguiente / anterior. Tab en la última celda crea una fila.
- **Enter**: celda de abajo; en la última fila sale de la tabla.
- Con el cursor dentro aparece una barrita para añadir o eliminar filas y columnas, poner la tabla a ancho completo, igualar columnas, cambiar el alto de filas (compacto, normal o amplio) o eliminar la tabla. Las mismas opciones salen al escribir `/` dentro de una celda.
- **Arrastrar**: pasa el ratón por el borde entre dos columnas (o por el borde derecho de la tabla) y arrastra para cambiar el ancho.
- **Igualar columnas** reparte el ancho de la tabla a partes iguales; si la tabla era automática, pasa a ocupar el 100 %.
- Se guardan como tablas Markdown normales (`| a | b |`). Si cambias anchos o alto, se añade un comentario invisible justo encima, que otros editores ignoran:

  ```markdown
  <!-- tabla: ancho=100 columnas=40,30,30 alto=compacto -->
  | ID | Descripción | Total |
  ```

## Bloques de código

- `/codigo` o ```` ``` ```` + Enter crean un bloque. Para indicar el lenguaje, escríbelo tras las comillas (```` ```python ````) o elígelo después en el bloque.
- Se colorea la sintaxis de Bash, C, C++, CSS, Go, HTML, Java, JavaScript, JSON, Markdown, Python, QML, Rust, SQL, TypeScript y YAML, con colores armonizados con el tema.
- Al pasar el ratón o poner el cursor dentro aparecen los botones: el lenguaje (arriba a la izquierda) abre la lista para cambiarlo; a la derecha están **copiar** y **eliminar bloque**.
- Enter y Shift+Enter crean líneas dentro del bloque; nunca sacan de él. Para salir: **Ctrl+Enter** (crea una línea debajo del bloque) o **flecha abajo** en la última línea. Las flechas también entran y salen.
- Retroceso en un bloque vacío lo convierte en texto normal.
- Dentro del bloque no se aplican atajos Markdown, formato ni el menú `/`: el texto se guarda tal cual.

## Pegar

- Desde una web o un documento se conservan los títulos, listas, negritas, enlaces, tablas y código, pero no las fuentes, colores ni tamaños.
- Un texto plano de varias líneas con sintaxis Markdown (`# `, `- `, ```` ``` ````, tablas) se convierte en bloques. Si no la tiene, cada línea pasa a ser un párrafo.
- Una sola línea se pega tal cual, sin interpretar `*` ni `#`.
- Código copiado de un editor o terminal (texto monoespaciado) se pega como bloque de código.
- Dentro de un bloque de código se pega siempre texto plano y queda dentro del bloque.
- Dentro de una celda el texto se pega en una sola línea, para no romper la tabla.
- **Ctrl+Shift+V** pega como texto plano, sin formato.

## Atajos

| Atajo | Acción |
| --- | --- |
| Ctrl+B / Ctrl+I / Ctrl+E | Negrita / cursiva / código sobre la selección |
| Ctrl+1 / Ctrl+2 / Ctrl+3 / Ctrl+0 | H1 / H2 / H3 / párrafo |
| Ctrl+L | Convertir en checkbox (o quitarlo) |
| Ctrl+Shift+L / Ctrl+Shift+O | Lista con viñetas / numerada |
| Ctrl+Shift+M | Alternar vista formateada / Markdown crudo |
| Ctrl+N / Ctrl+O / Ctrl+S / Ctrl+W / Esc | Nueva / abrir / guardar / cerrar pestaña / cerrar panel |

## Notas

- Las notas nuevas se llaman `nota-<fecha>.md` y se renombran solas con su primer `# título`.
- Se guardan automáticamente; borrar mueve el archivo a la papelera (`gio trash`).
- Si el archivo cambia fuera del panel (otro editor, `git pull`), se recarga.
- Ajustes del plugin: carpeta de notas, ancho del panel y lado (izquierda/derecha).

## Limitaciones

- La vista formateada usa la fuente normal del sistema, no la monoespaciada: Qt guarda el texto en fuente monoespaciada como `código`.
- Qt normaliza el Markdown al guardar (por ejemplo `*` puede quedar como `-` y los párrafos largos se envuelven a ~80 columnas). El contenido no cambia.
- Tras un autoformato no se puede deshacer con Ctrl+Z.
- El formato dentro del encabezado de una tabla (negrita, código...) no se guarda: Qt lo descarta al escribir el Markdown.
- Las tablas no admiten celdas combinadas ni varias líneas por celda, y la alineación de columnas (`:---:`) se pierde.
- El alto se ajusta para toda la tabla, no fila a fila: Qt ignora la altura de las filas.
- No hay bloques arrastrables.
- Los bloques de código no ajustan las líneas largas y los tabuladores se guardan como 4 espacios.
- Un bloque de código al inicio o al final de la nota lleva una línea en blanco (NBSP) al lado para poder escribir antes o después.

## Desarrollo

Guía de arquitectura para agentes y colaboradores: [AGENTS.md](AGENTS.md).

Requiere Qt 6 (`qmltestrunner`) para los tests del editor:

```bash
pnpm install   # instala husky + commitlint
pnpm test
```

Los commits siguen [Conventional Commits](https://www.conventionalcommits.org/) y se validan con commitlint.
