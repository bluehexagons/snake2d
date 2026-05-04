# snake2d — Improvements Plan

Issues found by reading every `.gd` file in the project. Ordered by severity.

---

## Bugs

### 1. High scores overwritten on first game after restart
**Files:** `autoload/game_manager.gd:23-26`, `autoload/game_manager.gd:67-90`

`GameManager` is an autoload, so its `_ready()` runs before `main.gd` sets dependencies. At the point `_ready()` fires, `save_data_util` is still `null`, so the `if save_data_util:` guard on line 25 skips the load entirely. `game_manager.high_scores` stays `[]` for the rest of startup.

When the first game ends, `end_game()` inserts the score into that empty array, then saves `[new_score]` — **overwriting whatever was on disk**.

Within a single session this doesn't matter (the array accumulates correctly after the first save), but every app restart wipes the leaderboard to one entry.

**Fix:** Load scores immediately after the dependency is injected:

```gdscript
# game_manager.gd
func set_save_data_util(save_data: RefCounted) -> void:
    save_data_util = save_data
    high_scores = save_data_util.load_high_scores()
```

---

### 2. `food.eat()` returns `null` on double-call
**File:** `scenes/food/food.gd:74-76`

```gdscript
func eat() -> Tween:
    if _eaten:
        return null   # ← null tween
```

`_consume_food()` in `gameplay.gd` doesn't await the tween, so this is harmless right now. But the return type is `Tween` and returning `null` is an implicit lie. If a caller ever does `await food.eat().finished` it crashes.

**Fix:** Either change return type to `void` (callers don't use it), or return a no-op tween:

```gdscript
func eat() -> Tween:
    if _eaten:
        var noop := create_tween()
        noop.tween_callback(func() -> void: pass)
        return noop
```

---

### 3. High scores menu polls every frame
**File:** `scenes/ui/high_scores_menu.gd:17-19`

```gdscript
func _process(delta: float) -> void:
    if not self.visible:
        return
    # ... polling code
```

The guard prevents logic execution when hidden, but the method still runs every frame. With `_process` this means a callback every 16ms regardless of visibility.

**Fix:** Disable processing by default and toggle via visibility signal:

```gdscript
func _ready() -> void:
    set_process(false)
    visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
    set_process(self.visible)
```

---

### 4. Silent call-order dependency in food consumption
**File:** `scenes/main/gameplay.gd:172-173`, `scenes/main/gameplay.gd:224`

```gdscript
# Line 172-173
snake.grow()
_consume_food()

# Line 224 (inside snake.grow)
segment.position = food.position  # ← depends on food still being valid
```

`segment.position = food.position` inside `grow()` is only safe because `_consume_food()` runs **after** `grow()` synchronously. Swapping those two lines would cause a null crash with no obvious explanation — the dependency is implicit in call order, not declared.

**Fix:** Pass the food position as a parameter to `grow()`, or cache it locally before calling grow:

```gdscript
var food_pos := food.global_position
snake.grow(food_pos)
_consume_food()
```

---

### 5. `reset_game()` routes through `end_game(0)`
**File:** `autoload/game_manager.gd:92-94`

```gdscript
func reset_game() -> void:
    end_game(0)  # This will handle cleanup and reset
```

`end_game` sets `is_running = false` and emits `game_over(0)`, which causes `main.gd` to transition to the game-over UI and set `game_over_score_label` to "Final Score: 0". The score-0 is filtered before saving, but the UI flash and state side-effects are unintended for a reset.

**Fix:** Implement reset as its own operation that resets state without emitting `game_over`, or just remove the method (it isn't called from anywhere in the current codebase).

---

### 6. `ConfirmationDialog` nodes are never freed
**File:** `scenes/ui/options_menu.gd:82-88`

`_show_confirmation_dialog` creates a `ConfirmationDialog`, adds it as a child, and calls `popup_centered()`. Neither the cancel path nor the close-button path calls `queue_free()`. Every dismissed dialog stays in the scene tree indefinitely. Reopening the options menu and dismissing dialogs repeatedly accumulates dead nodes, and each `confirmed.connect` adds another signal connection that never disconnects.

**Fix:** Free the dialog on both outcomes:

```gdscript
dialog.confirmed.connect(func() -> void: on_confirm.call(); dialog.queue_free())
dialog.close_requested.connect(dialog.queue_free)
dialog.canceled.connect(dialog.queue_free)
add_child(dialog)
dialog.popup_centered()
```

---

## Code Quality

### 7. Global input state set in instance code
**File:** `scenes/snake/snake.gd:22-23`

```gdscript
Input.set_emulate_touch_from_mouse(true)
Input.set_emulate_touch_from_mouse(true)
```

These modify global singleton state from an instanced scene. Every snake instantiation (every game restart) resets these flags, and they're never cleared when the snake is freed. If the project settings already control this, the code is redundant; if project settings don't set it, this makes the behavior tied to the snake's lifetime rather than the app's.

**Fix:** Move to Project Settings → Input Devices → Pointing → Emulate Touch From Mouse (or delete if already configured in editor).

---

### 8. Unused `ui_state_manager` field in GameManager
**Files:** `autoload/game_manager.gd:21`, `autoload/game_manager.gd:127-128`

`set_ui_state_manager()` assigns to `self.ui_state_manager`, but no method in `game_manager.gd` ever reads this field. It's a dead dependency — a dependency injection that implies coupling that doesn't exist.

**Fix:** Delete the field and setter if unused, or wire up actual usage if the coupling was intended.

---

### 9. Dead speed constants in config.gd
**File:** `autoload/config.gd:8-10`

```gdscript
const STARTING_SPEED: float = 7.0
const SPEED_INCREMENT: float = 0.5
const MAX_SPEED: float = 20.0
```

These are never referenced. Gameplay uses `BASE_TIMER_WAIT`, `MIN_TIMER_WAIT`, and `SPEED_INCREASE_PER_SEGMENT` defined locally in `gameplay.gd:16-18`. The config constants imply a "speed in cells/sec" model that doesn't match the timer-based implementation.

**Fix:** Delete the three unused constants, or replace them with the actual timer constants and reference them from `gameplay.gd`.

---

### 10. `snake_camera.gd` property named `game_manager` holds a `Gameplay` node
**Files:** `scenes/main/snake_camera.gd:9`, `scenes/main/main.gd:57`

```gdscript
# main.gd
camera_node.game_manager = gameplay   # `gameplay` is the Gameplay node, not GameManager
```

The camera only calls `Gameplay` methods (`get_snake_position`, `get_food_position`, etc.). The mislabeled property means the code reads like the camera depends on GameManager when it actually depends on Gameplay.

**Fix:** Rename the property in `snake_camera.gd` to `gameplay` and update the assignment in `main.gd`.

---

### 11. Double pause dispatch path
**Files:** `scenes/ui/ui_state_manager.gd:113-116`, `scenes/main/main.gd:218-223`

`UIStateManager.set_paused()` calls `game_manager.set_paused()` directly (line 116) **and** emits `pause_state_changed`, which `main._on_pause_state_changed()` handles by calling `game_manager.pause_game()` again. The second call is silenced by the guard in `pause_game` (`if not is_running or is_paused: return`), so there's no observable bug today — but this is fragile: the behavior depends on the guard remaining idempotent.

**Fix:** Remove the direct `game_manager.set_paused()` call from `UIStateManager.set_paused()` and let the `pause_state_changed` signal be the single dispatch path (which `main.gd` already handles).

---

### 12. Death color computation swaps R and G channels
**File:** `scenes/main/gameplay.gd:253-258`

```gdscript
segment.color = Color(
    lerp(current_color.g, 0.8, 0.5),  # red ← green value
    current_color.r * 0.1,             # green ← red value
    current_color.b * 0.1,
    current_color.a
)
```

For the current green snake (`r≈0.09, g≈0.74`) this accidentally produces a convincing brownish-red. If the snake color ever changes, this will break in a hard-to-diagnose way.

**Fix:** Lerp toward an explicit target color:

```gdscript
var dead_color := Color(0.78, 0.12, 0.12, current_color.a)
segment.color = current_color.lerp(dead_color, 0.6)
```

---

## Low Priority / Nice-to-Have

### 13. `is_position_occupied` uses raw float division for grid comparison
**File:** `scenes/main/gameplay.gd:100-111`

Positions are always set as `n * GRID_SIZE`, so the division is exact in practice. Using `pos.snapped(Vector2.ONE * ConfigData.GRID_SIZE)` instead of dividing would make the intent clearer and be safe if sub-grid positions are ever introduced.

### 14. `main.gd` mixes scene wiring with game flow logic (341 lines)
`_ready()` handles dependency injection, button wiring, animation polish installation, high score loading, window resize setup, and initial visibility state. The file isn't broken, but splitting button wiring and polish into helper methods would make the flow easier to follow.