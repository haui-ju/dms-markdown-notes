import QtQuick
import QtTest
import "../src/panel/logic/tab_order.js" as TabOrder

TestCase {
    name: "tab_order"

    function test_visible_slots() {
        compare(TabOrder.visibleSlotCount(0), 1);
        compare(TabOrder.visibleSlotCount(1), 1);
        compare(TabOrder.visibleSlotCount(2), 2);
        compare(TabOrder.visibleSlotCount(3), 3);
        compare(TabOrder.visibleSlotCount(10), 3);
    }

    function test_strip_drop_horizontal() {
        const w = 100;
        const sp = 4;
        compare(TabOrder.stripDropIndex(0, 0, false, 5, w, 32, sp), 0);
        compare(TabOrder.stripDropIndex(50, 0, false, 5, w, 32, sp), 0);
        compare(TabOrder.stripDropIndex(55, 0, false, 5, w, 32, sp), 1);
        compare(TabOrder.stripDropIndex(104, 0, false, 5, w, 32, sp), 1);
        compare(TabOrder.stripDropIndex(208, 0, false, 5, w, 32, sp), 2);
        compare(TabOrder.stripDropIndex(-1, 0, false, 5, w, 32, sp), -1);
    }

    function test_strip_drop_vertical() {
        const h = 32;
        const sp = 4;
        compare(TabOrder.stripDropIndex(0, 0, true, 4, 100, h, sp), 0);
        compare(TabOrder.stripDropIndex(0, 40, true, 4, 100, h, sp), 1);
        compare(TabOrder.stripDropIndex(0, 200, true, 4, 100, h, sp), 3);
    }

    function test_overflow_drop() {
        compare(TabOrder.overflowDropIndex(0, 3, 5), 3);
        compare(TabOrder.overflowDropIndex(1, 3, 5), 4);
        compare(TabOrder.overflowDropIndex(2, 3, 5), 4);
        compare(TabOrder.overflowDropIndex(0, 3, 3), -1);
    }

    function test_overflow_row() {
        compare(TabOrder.overflowRowIndex(8, 32, 4, 8), 0);
        compare(TabOrder.overflowRowIndex(28, 32, 4, 8), 1);
        compare(TabOrder.overflowRowIndex(44, 32, 4, 8), 1);
        compare(TabOrder.overflowRowIndex(4, 32, 4, 8), -1);
    }

    function test_pick_drop_strip() {
        const idx = TabOrder.pickDropIndex({
            tabCount: 5,
            px: 110,
            py: 10,
            vertical: false,
            tabWidth: 100,
            tabHeight: 32,
            spacing: 4,
            horizontalSlots: 3,
            strip: { x: 0, y: 0, w: 320, h: 36 },
            overflow: { open: false }
        });
        compare(idx, 1);
    }

    function test_pick_drop_overflow_list() {
        const idx = TabOrder.pickDropIndex({
            tabCount: 5,
            px: 50,
            py: 90,
            vertical: false,
            tabWidth: 100,
            tabHeight: 32,
            spacing: 4,
            horizontalSlots: 3,
            strip: { x: 0, y: 0, w: 320, h: 36 },
            overflow: { open: true, x: 20, y: 60, w: 200, h: 120, listY: 68 }
        });
        compare(idx, 4);
    }

    function test_pick_drop_gap_bridge() {
        const idx = TabOrder.pickDropIndex({
            tabCount: 5,
            px: 50,
            py: 48,
            vertical: false,
            tabWidth: 100,
            tabHeight: 32,
            spacing: 4,
            horizontalSlots: 3,
            strip: { x: 0, y: 0, w: 320, h: 36 },
            overflow: { open: true, x: 20, y: 60, w: 200, h: 120, listY: 68 }
        });
        compare(idx, 3);
    }

    function test_pick_drop_vertical_column() {
        const idx = TabOrder.pickDropIndex({
            tabCount: 4,
            px: 10,
            py: 72,
            vertical: true,
            tabWidth: 160,
            tabHeight: 32,
            spacing: 4,
            horizontalSlots: 3,
            strip: { x: 0, y: 0, w: 188, h: 400 }
        });
        compare(idx, 2);
    }

    function test_move_tab_reorder() {
        const tabs = ["/a", "/b", "/c", "/d"];
        let r = TabOrder.moveTab(tabs, 0, 3, 0);
        compare(JSON.stringify(r.tabs), JSON.stringify(["/d", "/a", "/b", "/c"]));
        compare(r.currentIndex, 1);

        r = TabOrder.moveTab(tabs, 2, 2, 0);
        compare(JSON.stringify(r.tabs), JSON.stringify(["/c", "/a", "/b", "/d"]));
        compare(r.currentIndex, 0);

        r = TabOrder.moveTab(tabs, 1, 0, 2);
        compare(JSON.stringify(r.tabs), JSON.stringify(["/b", "/c", "/a", "/d"]));
        compare(r.currentIndex, 0);
    }

    function test_move_overflow_to_bar() {
        const tabs = ["/a", "/b", "/c", "/d", "/e"];
        const r = TabOrder.moveTab(tabs, 4, 4, 1);
        compare(JSON.stringify(r.tabs), JSON.stringify(["/a", "/e", "/b", "/c", "/d"]));
        compare(r.currentIndex, 1);
        compare(TabOrder.visibleSlotCount(r.tabs.length), 3);
        compare(r.tabs[0], "/a");
        compare(r.tabs[1], "/e");
        compare(r.tabs[2], "/b");
    }

    function test_move_noop() {
        const tabs = ["/a", "/b"];
        const r = TabOrder.moveTab(tabs, 0, 0, 0);
        compare(JSON.stringify(r.tabs), JSON.stringify(tabs));
        compare(r.currentIndex, 0);
    }
}
