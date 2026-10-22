local _, LB = ...

-- Field guide panel rules: size limits and combat behaviour. Pure.
local FieldView = {}
LB.FieldView = FieldView

FieldView.DEFAULT_WIDTH, FieldView.DEFAULT_HEIGHT = 330, 470
FieldView.MIN_WIDTH, FieldView.MAX_WIDTH = 280, 420
FieldView.MIN_HEIGHT, FieldView.MAX_HEIGHT = 300, 800
FieldView.FADED_ALPHA = 0.35
FieldView.COMBAT_POLICIES = { show = true, hide = true, fade = true }

-- policy: show | hide | fade. Text stays readable when faded: only the background dims.
function FieldView.CombatState(policy, inCombat)
    if inCombat and policy == "hide" then
        return { shown = false, backgroundAlpha = 1 }
    end
    if inCombat and policy == "fade" then
        return { shown = true, backgroundAlpha = FieldView.FADED_ALPHA }
    end
    return { shown = true, backgroundAlpha = 1 }
end

function FieldView.ClampSize(width, height)
    return math.max(FieldView.MIN_WIDTH, math.min(FieldView.MAX_WIDTH, width)),
        math.max(FieldView.MIN_HEIGHT, math.min(FieldView.MAX_HEIGHT, height))
end
