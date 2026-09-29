---
title: Ejemplo completo
tags: [ejemplo, markdown-notes]
creado: 2026-09-29
---

# Ejemplo completo

Esta nota enseña todo lo que hace **Markdown Notes**. Ábrela con el menú `…` →
Ver Markdown (**Ctrl+Shift+M**) para ver el archivo tal cual: es Markdown normal,
así que también se lee en Obsidian, GitHub o cualquier editor. El bloque de
propiedades de arriba (front matter) no se ve aquí, pero se conserva. #ejemplo

## Formato de texto

Texto con **negrita**, *cursiva*, ~~tachado~~, `código en línea` y un 
[enlace a la web](https://github.com/haui-ju/dms-markdown-notes). Se escriben
con los atajos Markdown o con **Ctrl+B**, **Ctrl+I** y **Ctrl+E** sobre la
selección.

El código en línea guarda los símbolos tal cual: `# no es título`, `- no es
lista`, `C:\Users\fer` y `**sin negrita**`.

### Títulos

Hay tres niveles: `# ` (H1), `## ` (H2) y `### ` (H3), o **Ctrl+1**, **Ctrl+2**, **Ctrl+3**. **Ctrl+0** vuelve a texto normal.

## Listas

- Viñeta con `- ` o `* `
- Otra viñeta
  - Anidada con Tab
  - Shift+Tab la saca
- Enter en una viñeta vacía termina la lista
1.  Lista numerada con `1. `
2.  Se numera sola
3.  **Ctrl+Shift+O** convierte la línea en numerada

## Tareas

- [x] Escribir `[] ` o `- [] ` crea una casilla
- [x] Clic en la casilla para marcarla
- [ ] **Ctrl+L** convierte la línea en tarea o la quita
- [ ] Preparar la versión #proyecto/release

## Citas

> Una cita se crea con `> `. Enter al final añade otro párrafo a la cita.
> 
> Enter en un párrafo vacío sale de ella.

- - -
## Enlaces entre notas y etiquetas

Los enlaces van entre corchetes dobles: [[Otra nota]]. Clic para abrirla; si
no existe, se crea. También valen [[Otra nota|con otro texto]] y [[Otra nota#Sección]].

Las etiquetas empiezan por `#`: #ejemplo, #proyecto/release, #idea. Clic en una
para ver las notas que la usan. **Ctrl+F** abre el buscador; escribe `#` para
ver todas las etiquetas.

## Tablas

`/tabla` crea una. Tab y Shift+Tab mueven entre celdas; con el cursor dentro
aparece la barra para añadir filas y columnas, cambiar el ancho o el alto.


<!-- tabla: ancho=100 columnas=34,22,44 -->
|Función|Atajo  |Notas                    |
|-------|-------|-------------------------|
|Negrita|**Ctrl+B**|Sobre la selección       |
| Código | `Ctrl+E` | Guarda `#`, `-` y `\|` tal cual |
|Buscar |Ctrl+F |`#etiqueta` filtra #ejemplo|
|Enlace |`[[...]]`|[[Otra nota]]           |

Una tabla sin comentario de layout usa el ancho automático:


|A|B|
|-|-|
|1|2|

## Bloques de código

Se crean con ```` ``` ```` y Enter o `/codigo`. El lenguaje se elige arriba a
la izquierda; a la derecha están copiar y eliminar.

```python
def etiquetas(nota):
    return [p[1:] for p in nota.split() if p.startswith("#")]
```
 

```bash
dms ipc call markdownNotes openNote "diario/$(date +%F)"
dms ipc call markdownNotes search "#ejemplo"
```
 

```json
{ "notesDir": "~/Notes", "noteFont": "Noto Sans" }
```
## Imágenes

Pega una imagen con **Ctrl+V** o usa `/imagen`. Se guarda en la carpeta `Ejemplo
completo/`, junto a la nota. Clic en ella abre el visor.

![Diagrama de ejemplo](Ejemplo%20completo/diagrama.png)

## Menú /

Escribe `/` al inicio de una línea para insertar bloques: texto, títulos,
listas, tareas, cita, separador, código, tabla e imagen. Lo que escribas
después filtra la lista (`/tab`, `/tareas`).

## Deshacer y guardar

**Ctrl+Z** deshace palabra por palabra y **Ctrl+Y** rehace. La nota se guarda
sola; **Ctrl+S** guarda ya.

