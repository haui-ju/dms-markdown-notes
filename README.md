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

Comandos IPC: `toggle`, `open`, `close`, `newNote`.

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

## Atajos

| Atajo | Acción |
| --- | --- |
| Ctrl+B / Ctrl+I / Ctrl+E | Negrita / cursiva / código sobre la selección |
| Ctrl+1 / Ctrl+2 / Ctrl+3 / Ctrl+0 | H1 / H2 / H3 / párrafo |
| Ctrl+L | Convertir en checkbox (o quitarlo) |
| Ctrl+Shift+L / Ctrl+Shift+O | Lista con viñetas / numerada |
| Ctrl+Shift+M | Alternar vista formateada / Markdown crudo |
| Ctrl+N / Ctrl+S / Esc | Nueva nota / guardar / cerrar |

## Notas

- Las notas nuevas se llaman `nota-<fecha>.md` y se renombran solas con su primer `# título`.
- Se guardan automáticamente; borrar mueve el archivo a la papelera (`gio trash`).
- Si el archivo cambia fuera del panel (otro editor, `git pull`), se recarga.
- Ajustes del plugin: carpeta de notas, ancho del panel y lado (izquierda/derecha).

## Limitaciones

- Qt normaliza el Markdown al guardar (por ejemplo `*` puede quedar como `-` y los párrafos largos se envuelven a ~80 columnas). El contenido no cambia.
- Tras un autoformato no se puede deshacer con Ctrl+Z.
- No hay menú `/`, bloques arrastrables ni edición visual de tablas (usa la vista Markdown).

## Desarrollo

Requiere Qt 6 (`qmltestrunner`) para los tests del editor:

```bash
pnpm install   # instala husky + commitlint
pnpm test
```

Los commits siguen [Conventional Commits](https://www.conventionalcommits.org/) y se validan con commitlint.
