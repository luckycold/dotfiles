// QML-importable plain JS; also executed verbatim by node:test via vm.
// Inputs are snapshots: never pass live QML widgets into the allocator.
function entryId(entry) {
    return typeof entry === "string" ? entry : (entry && entry.id ? String(entry.id) : "");
}

function centerIndex(entries, id) {
    for (var i = 0; i < entries.length; ++i)
        if (entryId(entries[i]) === id) return i;
    return -1;
}

function lane(slot, center, anchorIndex) {
    if (slot.region === "left" || slot.region === "right") return slot.region;
    if (slot.region !== "center") return "";
    var index = centerIndex(center, slot.id);
    if (index < 0 || index === anchorIndex) return "";
    return index < anchorIndex ? "left" : "right";
}

function nonnegative(value) {
    return typeof value === "number" && isFinite(value) ? Math.max(0, value) : 0;
}

// Total widget width, not the label viewport. Minima are preserved on overflow.
// Native ModuleList spacing is zero; gap reserves ONE inter-group gap per lane.
function allocate(config, ownIndex) {
    var slots = config.slots || [];
    var center = config.center || [];
    var anchorIndex = centerIndex(center, config.anchorId);
    if (config.vertical || anchorIndex < 0 || ownIndex < 0 || ownIndex >= slots.length
            || !isFinite(config.anchorX) || !(config.anchorWidth > 0)
            || !isFinite(config.windowWidth) || config.windowWidth <= 0) return -1;
    var own = slots[ownIndex];
    if (!own || own.visible === false || !own.fill) return -1;
    var side = lane(own, center, anchorIndex);
    if (!side) return -1;
    var available = side === "left" ? config.anchorX
        : config.windowWidth - config.anchorX - config.anchorWidth;
    available -= nonnegative(config.edge) + nonnegative(config.gap);
    var fixed = 0;
    var minima = 0;
    var count = 0;
    for (var i = 0; i < slots.length; ++i) {
        var slot = slots[i];
        if (!slot || slot.visible === false || lane(slot, center, anchorIndex) !== side) continue;
        if (slot.fill) {
            minima += nonnegative(slot.minimum);
            count++;
        } else {
            fixed += nonnegative(slot.width);
        }
    }
    return nonnegative(own.minimum) + Math.max(0, available - fixed - minima) / count;
}
