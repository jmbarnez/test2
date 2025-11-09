local math_util = {}

-- Constant representing a full turn in radians
math_util.TAU = math.pi * 2

function math_util.clamp_angle(angle)
    angle = angle % math_util.TAU
    if angle > math.pi then
        angle = angle - math_util.TAU
    elseif angle < -math.pi then
        angle = angle + math_util.TAU
    end
    return angle
end

return math_util
