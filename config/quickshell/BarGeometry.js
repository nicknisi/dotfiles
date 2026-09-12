// Pointer coordinates are local to the edge window, not the monitor.
function nearestEdge(edge, screenWidth, screenHeight, windowWidth, windowHeight, x, y) {
    const px = Math.max(0, Math.min(screenWidth, x + (edge === "right" ? screenWidth - windowWidth : 0)));
    const py = Math.max(0, Math.min(screenHeight, y + (edge === "bottom" ? screenHeight - windowHeight : 0)));
    const distances = { top: py, bottom: screenHeight - py, left: px, right: screenWidth - px };
    let best = edge;
    for (const candidate in distances)
        if (distances[candidate] < distances[best]) best = candidate;
    return best;
}
