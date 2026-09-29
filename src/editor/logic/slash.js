.pragma library

var BLOCKS = [
    {
        id: "p",
        label: "Texto",
        icon: "notes",
        keywords: "parrafo normal text paragraph"
    },
    {
        id: "h1",
        label: "Título 1",
        icon: "format_h1",
        keywords: "heading encabezado h1"
    },
    {
        id: "h2",
        label: "Título 2",
        icon: "format_h2",
        keywords: "heading encabezado subtitulo h2"
    },
    {
        id: "h3",
        label: "Título 3",
        icon: "format_h3",
        keywords: "heading encabezado subtitulo h3"
    },
    {
        id: "bullet",
        label: "Lista",
        icon: "format_list_bulleted",
        keywords: "vinetas bullet ul"
    },
    {
        id: "number",
        label: "Lista numerada",
        icon: "format_list_numbered",
        keywords: "ordenada numeros ol"
    },
    {
        id: "task",
        label: "Lista de tareas",
        icon: "checklist",
        keywords: "tarea check checkbox todo pendiente"
    },
    {
        id: "quote",
        label: "Cita",
        icon: "format_quote",
        keywords: "quote blockquote"
    },
    {
        id: "rule",
        label: "Separador",
        icon: "horizontal_rule",
        keywords: "divisor linea divider hr"
    },
    {
        id: "code",
        label: "Bloque de código",
        icon: "code",
        keywords: "codigo code fence"
    },
    {
        id: "table",
        label: "Tabla",
        icon: "table",
        keywords: "table grid"
    }
];

var TABLE = [
    {
        id: "rowAdd",
        label: "Añadir fila",
        icon: "add_row_below",
        keywords: "agregar nueva fila row"
    },
    {
        id: "columnAdd",
        label: "Añadir columna",
        icon: "add_column_right",
        keywords: "agregar nueva columna column"
    },
    {
        id: "rowRemove",
        label: "Eliminar fila",
        icon: "playlist_remove",
        keywords: "borrar quitar fila row"
    },
    {
        id: "columnRemove",
        label: "Eliminar columna",
        icon: "variable_remove",
        keywords: "borrar quitar columna column"
    },
    {
        id: "fullWidth",
        label: "Ancho completo",
        icon: "fit_width",
        keywords: "expandir ancho completo 100 full width"
    },
    {
        id: "equalize",
        label: "Igualar columnas",
        icon: "horizontal_distribute",
        keywords: "equilibrar distribuir igualar columnas mismo ancho"
    },
    {
        id: "density",
        label: "Alto de filas",
        icon: "density_medium",
        keywords: "altura densidad compacto normal amplio filas"
    },
    {
        id: "tableRemove",
        label: "Eliminar tabla",
        icon: "delete",
        keywords: "borrar quitar tabla table"
    }
];

var MAX_QUERY = 24;

function fold(s) {
    return s.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

function filter(commands, query) {
    const q = fold(query).trim();
    if (!q)
        return commands.slice();
    const tokens = q.split(/\s+/);
    const scored = [];
    commands.forEach((cmd, order) => {
        const label = fold(cmd.label);
        const words = (label + " " + cmd.keywords).split(/\s+/);
        let score = -1;
        if (label.startsWith(q))
            score = 0;
        else if (tokens.every(t => words.some(w => w.startsWith(t))))
            score = 1;
        if (score >= 0)
            scored.push({
                cmd: cmd,
                score: score,
                order: order
            });
    });
    scored.sort((a, b) => a.score - b.score || a.order - b.order);
    return scored.map(s => s.cmd);
}
