.pragma library

function visibleSlotCount(tabCount) {
    const n = tabCount | 0;
    if (n >= 3)
        return 3;
    return Math.max(1, n);
}

function stripDropIndex(localX, localY, vertical, tabCount, tabWidth, tabHeight, spacing) {
    const n = tabCount | 0;
    if (n <= 0)
        return -1;
    const extent = vertical ? tabHeight : tabWidth;
    const step = extent + spacing;
    const coord = vertical ? localY : localX;
    if (coord < 0)
        return -1;
    const slot = Math.floor(coord / Math.max(1, step));
    const within = coord - slot * step;
    let index = slot;
    if (within > extent / 2)
        index = slot + 1;
    return Math.max(0, Math.min(n - 1, index));
}

function overflowRowIndex(localY, rowHeight, spacing, topPadding) {
    const y = localY - (topPadding || 0);
    if (y < 0)
        return -1;
    const step = rowHeight + spacing;
    const row = Math.floor(y / Math.max(1, step));
    const within = y - row * step;
    if (within > rowHeight / 2)
        return row + 1;
    return row;
}

function overflowDropIndex(row, horizontalSlots, tabCount) {
    const slots = horizontalSlots | 0;
    const n = tabCount | 0;
    const overflowCount = n - slots;
    if (overflowCount <= 0 || row < 0)
        return -1;
    const idx = slots + row;
    return Math.max(slots, Math.min(n - 1, idx));
}

function inRect(px, py, rx, ry, rw, rh) {
    return px >= rx && py >= ry && px < rx + rw && py < ry + rh;
}

function pickDropIndex(opts) {
    const n = opts.tabCount | 0;
    if (n <= 1)
        return -1;
    const px = opts.px;
    const py = opts.py;
    const vertical = !!opts.vertical;
    const tabWidth = opts.tabWidth;
    const tabHeight = opts.tabHeight | 0;
    const spacing = opts.spacing | 0;
    const slots = opts.horizontalSlots | 0;

    const strip = opts.strip;
    if (strip && inRect(px, py, strip.x, strip.y, strip.w, strip.h)) {
        const lx = px - strip.x;
        const ly = py - strip.y;
        return stripDropIndex(lx, ly, vertical, n, tabWidth, tabHeight, spacing);
    }

    const ov = opts.overflow;
    if (!vertical && ov && ov.open) {
        const bridgeY = strip ? strip.y + strip.h : ov.y;
        const bridgeH = Math.max(ov.y + ov.h - bridgeY, 0);
        const hitX = ov.x;
        const hitW = ov.w;
        if (bridgeH > 0 && inRect(px, py, hitX, bridgeY, hitW, bridgeH)) {
            const innerY = py - ov.listY;
            if (py < ov.listY) {
                return Math.min(n - 1, slots);
            }
            const row = overflowRowIndex(innerY, tabHeight, spacing, 0);
            const hit = overflowDropIndex(row, slots, n);
            if (hit >= 0)
                return hit;
        }
    }

    return -1;
}

function moveTab(tabs, currentIndex, from, to) {
    const list = tabs.slice();
    const n = list.length;
    const f = from | 0;
    const t = to | 0;
    let cur = currentIndex | 0;
    if (f < 0 || f >= n || t < 0 || t >= n || f === t)
        return { tabs: list, currentIndex: cur };
    const path = list.splice(f, 1)[0];
    list.splice(t, 0, path);
    if (cur === f)
        cur = t;
    else if (f < cur && t >= cur)
        cur--;
    else if (f > cur && t <= cur)
        cur++;
    return { tabs: list, currentIndex: cur };
}
