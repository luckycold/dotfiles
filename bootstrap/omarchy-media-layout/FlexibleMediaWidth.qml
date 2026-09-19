import QtQuick
import Quickshell
import qs.Commons
import "MediaWidthAllocator.js" as Allocator

// Keep this and MediaWidthAllocator.js alongside each participating widget.
// The native bar remains responsible for windows, slots and service facades.
Item {
    id: root
    required property var widget
    property string anchorId: "omarchy.clock"
    readonly property real edgePadding: Style.space(8)
    readonly property real laneGap: Style.space(8)
    readonly property real allocatedWidth: calculateWidth()

    // A visual-only walk. Stop at ModuleSlot boundaries: do not visit widget
    // internals, service objects, popup roots, or the allocator itself.
    function collectSlots(node, result) {
        if (!node) return;
        if ("moduleName" in node && "region" in node && "activeItem" in node) {
            result.push(node);
            return;
        }
        var children = node.children;
        if (!children) return;
        for (var i = 0; i < children.length; ++i)
            collectSlots(children[i], result);
    }

    function calculateWidth() {
        if (!widget || !widget.fillMediaWidth || !widget.bar || widget.bar.vertical) return -1;
        var window = widget.QsWindow.window;
        if (!window || !window.contentItem) return -1;
        var content = window.contentItem;
        var layout = widget.bar.layoutConfig;
        var center = layout && layout.center ? layout.center : [];
        if (Allocator.centerIndex(center, anchorId) < 0) return -1;

        var slots = [];
        collectSlots(content, slots);
        var records = [];
        var ownIndex = -1;
        var anchor = null;
        for (var i = 0; i < slots.length; ++i) {
            var slot = slots[i];
            var item = slot.activeItem;
            // Effective Item.visible also excludes invisible ancestor lists.
            if (!item || !slot.visible || !item.visible) continue;
            var fill = "fillMediaWidth" in item && item.fillMediaWidth;
            var record = {id: slot.moduleName, region: slot.region, visible: true, fill: fill};
            if (fill) {
                // NEVER read a flexible item's width/implicitWidth, nor its
                // slot's geometry: those depend on this allocation.
                record.minimum = item.minimumMediaWidth;
            } else {
                record.width = item.implicitWidth;
            }
            if (item === widget) ownIndex = records.length;
            if (record.region === "center" && record.id === anchorId && !fill)
                anchor = slot;
            records.push(record);
        }
        if (ownIndex < 0 || !anchor) return -1;

        // Native centerAnchorModule is centered independently of its siblings.
        // Explicit x reads subscribe to ancestor movement; mapToItem alone does
        // not establish those dependencies. Only the fixed anchor chain is read.
        var anchorX = 0;
        var ancestor = anchor;
        while (ancestor && ancestor !== content) {
            anchorX += ancestor.x;
            ancestor = ancestor.parent;
        }
        if (ancestor !== content) return -1;
        return Allocator.allocate({
            slots: records,
            center: center,
            anchorId: anchorId,
            anchorX: anchorX,
            anchorWidth: anchor.width,
            windowWidth: window.width,
            edge: edgePadding,
            gap: laneGap
        }, ownIndex);
    }
}
