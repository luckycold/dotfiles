# FreshRSS touch-card gesture extensions

Use this when a FreshRSS user extension turns `.flux` entries into swipeable cards with Pointer Events.

## Commit animation for non-dismissive actions

A swipe threshold confirms an action; it does not necessarily mean the card should be dismissed. For actions such as favorite, read/unread, save, open reader, or open website, keep the entry in the stream and animate it directly back to its starting position:

1. During horizontal drag, update a CSS custom property such as `--card-drag-x` and reveal the directional action indicator.
2. On a committed `pointerup`, remove the dragging class and add a settling class.
3. Set `--card-drag-x` to `0px` and indicator progress to `0` immediately. Let the existing transform transition animate the card home.
4. Suppress the synthetic post-touch click for slightly longer than the settling transition.
5. Execute the configured action at the end of the settling transition, then clear transient classes/properties.

Do not calculate `card.width + margin` and translate the card off-screen unless the action truly removes/dismisses the item. Sliding a persistent card off-screen and later restoring it falsely communicates deletion and creates a distracting double movement.

Example commit shape:

```js
function commitGesture(gesture, direction, action) {
  const card = gesture.card;
  card.classList.remove('card-dragging');
  card.classList.add('card-settling');
  card.style.setProperty('--card-drag-x', '0px');
  setIndicatorProgress(card, 0, direction);
  suppressClickUntil = Date.now() + 450;

  window.setTimeout(async () => {
    await executeAction(action, card);
    updateActionPresentation(card);
  }, 210);

  window.setTimeout(() => resetCard(card), 360);
}
```

Keep the action delay aligned with the CSS settling duration. If an action removes the entry under the current filter, execute it only after the return animation so the card does not disappear midway through settling.

## Regression testing with jsdom

Test the visible contract rather than only checking source text:

- Build a minimal `main#stream > .flux > .flux_header` fixture containing the action target.
- Stub `getBoundingClientRect()` with a realistic card width so threshold math is deterministic.
- jsdom may not implement `PointerEvent`; create a cancelable `MouseEvent` and define `pointerId`, `pointerType: 'touch'`, and `isPrimary` properties.
- If the extension waits for `DOMContentLoaded`, explicitly dispatch that event after evaluating the deferred script.
- Dispatch `pointerdown`, a horizontal `pointermove` beyond the commit threshold, then `pointerup`.
- Assert the drag value follows the finger during movement and becomes `0px` immediately after the committed release.
- Also assert the settling class and action timing where practical.

Follow RED-GREEN-REFACTOR: the regression should first fail with the old off-screen distance (for example `-332px !== 0px`), then pass after the commit behavior changes.

## Deployment verification

For a persistent TrueNAS FreshRSS extension:

- Back up the target extension, affected user config, and PostgreSQL before deployment.
- Stage changed files and compare SHA-256 hashes before and after copying.
- Preserve the live extension ownership and modes.
- Run JavaScript syntax checks and PHP lint for extension entry/config files.
- Confirm the extension remains enabled.
- Perform a managed `app.stop` / `app.start`, then require FreshRSS `RUNNING`, the container healthy, matching deployed hashes, and the new metadata version.
