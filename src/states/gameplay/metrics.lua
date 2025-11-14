local Metrics = {}

local SAMPLE_WINDOW = 120

local function get_time()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return nil
end

local function record_metric(container, key, value)
    if not container or type(value) ~= "number" then
        return
    end

    local bucket = container[key]
    if not bucket then
        bucket = {
            values = {},
            cursor = 1,
            count = 0,
            sum = 0,
            window = SAMPLE_WINDOW,
        }
        container[key] = bucket
    end

    local window = bucket.window or SAMPLE_WINDOW
    local cursor = bucket.cursor or 1

    if bucket.count < window then
        bucket.count = bucket.count + 1
    else
        local old = bucket.values[cursor]
        if old then
            bucket.sum = bucket.sum - old
        end
    end

    bucket.values[cursor] = value
    bucket.sum = (bucket.sum or 0) + value
    bucket.last = value

    bucket.avg = bucket.count > 0 and (bucket.sum / bucket.count) or value

    local minValue, maxValue = value, value
    for i = 1, bucket.count do
        local sample = bucket.values[i]
        if sample then
            minValue = math.min(minValue, sample)
            maxValue = math.max(maxValue, sample)
        end
    end

    bucket.min = minValue
    bucket.max = maxValue
    bucket.cursor = (cursor % window) + 1
end

local function update_performance_strings(state)
    if not state then
        return
    end

    local metrics = state.performanceStatsRecords
    if not metrics then
        state.performanceStats = nil
        return
    end

    local METRIC_ORDER = { "frame_dt_ms", "update_ms", "render_ms" }
    local METRIC_LABELS = {
        frame_dt_ms = "Frame dt",
        update_ms = "Update",
        render_ms = "Render",
    }

    local lines = {}
    for i = 1, #METRIC_ORDER do
        local key = METRIC_ORDER[i]
        local bucket = metrics[key]
        if bucket and bucket.last then
            local avg = bucket.avg or bucket.last
            local minv = bucket.min or bucket.last
            local maxv = bucket.max or bucket.last
            local last = bucket.last
            lines[#lines + 1] = string.format(
                "%s: avg %.2fms (%.2f-%.2f) last %.2f",
                METRIC_LABELS[key] or key,
                avg,
                minv,
                maxv,
                last
            )
        end
    end

    state.performanceStats = lines
end

local function ensure_metrics_container(state)
    if not state then
        return nil
    end

    local metrics = state.performanceStatsRecords
    if not metrics then
        metrics = {}
        state.performanceStatsRecords = metrics
    end

    return metrics
end

function Metrics.beginUpdate(state, dt)
    local metrics = ensure_metrics_container(state)
    if dt and metrics then
        record_metric(metrics, "frame_dt_ms", dt * 1000)
    end
    return get_time()
end

function Metrics.finalizeUpdate(state, start_time)
    if not state then
        return
    end

    local metrics = state.performanceStatsRecords
    if metrics and start_time then
        local stop = get_time()
        if stop then
            record_metric(metrics, "update_ms", math.max(0, (stop - start_time) * 1000))
        end
    end

    update_performance_strings(state)
end

function Metrics.beginRender(state)
    ensure_metrics_container(state)
    return get_time()
end

function Metrics.finalizeRender(state, start_time)
    if not state then
        return
    end

    local metrics = state.performanceStatsRecords
    if metrics and start_time then
        local stop = get_time()
        if stop then
            record_metric(metrics, "render_ms", math.max(0, (stop - start_time) * 1000))
        end
    end

    update_performance_strings(state)
end

return Metrics
