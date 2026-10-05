import QtQuick
import "logic/images.js" as Images

QtObject {
    id: root

    required property var editor
    property int _menuEpoch: 0
    property var menuTarget: null

    function openFromModel(data) {
        if (!data || editor.sourceMode)
            return;
        const target = {
            ordinal: data.ordinal,
            pos: data.pos,
            x: data.x,
            y: data.y,
            width: data.width,
            height: data.height,
            mini: !!data.mini,
            caption: data.caption || "",
            url: data.url || "",
            src: data.src || "",
            alt: data.alt || ""
        };
        const epoch = _menuEpoch;
        menuTarget = null;
        Qt.callLater(() => {
            if (epoch !== root._menuEpoch)
                return;
            menuTarget = target;
        });
    }

    function viewImage() {
        if (!menuTarget)
            return;
        const pos = menuTarget.pos;
        const url = menuTarget.url;
        const src = menuTarget.src;
        const alt = menuTarget.alt;
        closeMenu();
        editor.imageActivated(pos, url, src, alt);
    }

    function closeMenu() {
        _menuEpoch++;
        menuTarget = null;
    }

    function applyMini(mini) {
        if (!menuTarget)
            return;
        const src = menuTarget.src;
        const ordinal = menuTarget.ordinal;
        closeMenu();
        let layouts = editor._imageGalleryLayouts;
        let md = editor.markdownText;
        if (!mini) {
            md = Images.setImageMini(md, ordinal, false, editor._imageMiniBySrc, layouts);
            layouts = Images.setSourceInLayouts(layouts, src, false, Images.MINI_SIZE);
            if (src)
                delete editor._imageMiniBySrc[src];
        } else {
            layouts = Images.setSourceInLayouts(layouts, src, true, Images.MINI_SIZE);
            if (src)
                editor._imageMiniBySrc[src] = true;
        }
        editor._imageGalleryLayouts = layouts;
        md = Images.applyGalleryLayouts(md, layouts);
        editor._syncGalleryLayoutsFromMd(md);
        if (!editor._imageGalleryLayouts.length && layouts.length)
            editor._imageGalleryLayouts = layouts;
        editor._markBefore();
        editor.replaceMarkdown(md);
        editor.refreshDecorations();
    }

    function removeImage() {
        if (!menuTarget)
            return;
        const src = menuTarget.src;
        const pos = menuTarget.pos;
        closeMenu();
        if (src) {
            editor._imageGalleryLayouts = Images.setSourceInLayouts(editor._imageGalleryLayouts, src, false, Images.MINI_SIZE);
            delete editor._imageMiniBySrc[src];
        }
        editor._markBefore();
        editor.removeImageAt(pos);
        editor.refreshDecorations();
    }

    function applyCaption(text) {
        if (!menuTarget)
            return;
        const ordinal = menuTarget.ordinal;
        closeMenu();
        const md = Images.setImageCaption(editor.markdownText, ordinal, text);
        if (md === editor.markdownText)
            return;
        editor._markBefore();
        editor.replaceMarkdown(md);
        editor.refreshDecorations();
    }
}
