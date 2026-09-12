.pragma library

// Return the popup window origin relative to its trigger. Padding surrounds
// the visible frame, so it is subtracted rather than added to the visible gap.
function position(edge, alignment, buttonWidth, buttonHeight, frameWidth, frameHeight, padding, gap) {
    const side = edge === "left" || edge === "right";
    const along = alignment === "center"
        ? ((side ? buttonHeight : buttonWidth) - (side ? frameHeight : frameWidth)) / 2
        : alignment === "start" ? 0
        : (side ? buttonHeight - frameHeight : buttonWidth - frameWidth);
    if (side) return {
        x: (edge === "left" ? buttonWidth + gap : -frameWidth - gap) - padding,
        y: along - padding
    };
    return {
        x: along - padding,
        y: (edge === "bottom" ? -frameHeight - gap : buttonHeight + gap) - padding
    };
}
