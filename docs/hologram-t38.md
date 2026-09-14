# T38: native buttons and brighter panels

The T37 screen panels still required a manual coordinate hit test before their
native `Activated` handlers could run. A second ContextActionService dispatcher
also consumed mouse and touch input. That left a visible button dependent on two
different input paths and allowed the manual path to reject a native activation.

T38 uses `GuiButton.Activated` as the sole action dispatcher. The HUD no longer
binds mouse/touch context actions or enumerates GUI objects to resolve a click.
The panel container is a Frame, with a separate transparent background button
below the action rows. Touch tracking only cancels drags and stale presses after
hiding, resizing, changing character, or suspending the HUD. Activation does not
require a preceding InputBegan event or matching projected coordinates.

Panels now use a white base and a blue/teal gradient (44/94/115 to 24/57/78).
Previously the dark base multiplied the already dark gradient. The drawer,
navigation and text are brighter, and action rows have more visible backgrounds.
Panels remain opaque so game gain popups do not obscure their controls.

The version is `4.31HOLO-T38`. The existing `RockBugHub_v1_5.lua` launch URL is
unchanged. Source outside the embedded HUD and version identifiers is identical
to T37; automation and the paid boss script are unchanged in this UI update.

Validation: 44 Luau scenarios passed (2 layouts, 38 HUD lifecycle/content,
4 original drawer controls). Coverage includes native touch/mouse activation,
both release orders, all overview actions and expansion links, all twelve full
sections, hidden/queued actions, drag cancellation, mobile rotation, and cleanup.
The launcher compiled with Luau 0.690; the generated bundle matches its source.
No live Roblox client or real device input test was available in this workspace.

API references: [GuiButton](https://create.roblox.com/docs/reference/engine/classes/GuiButton)
and [UIGradient](https://create.roblox.com/docs/reference/engine/classes/UIGradient).
