require 'cairo'
-- require 'cairo_xlib'

local PI = math.pi

local function rgba(hex, a)
    local r = tonumber(hex:sub(1,2),16)/255
    local g = tonumber(hex:sub(3,4),16)/255
    local b = tonumber(hex:sub(5,6),16)/255
    return r, g, b, a or 1
end

local DNI  = {'NIEDZIELA','PONIEDZIAŁEK','WTOREK','ŚRODA','CZWARTEK','PIĄTEK','SOBOTA'}
local MIES = {'stycznia','lutego','marca','kwietnia','maja','czerwca','lipca',
              'sierpnia','września','października','listopada','grudnia'}

local function centered(cr, txt, cx, y, size, col)
    cairo_select_font_face(cr, 'Monaspace Krypton Frozen', CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, size)
    cairo_set_source_rgba(cr, rgba(col, 1))
    local e = cairo_text_extents_t:create()
    cairo_text_extents(cr, txt, e)
    cairo_move_to(cr, cx - e.width/2 - e.x_bearing, y)
    cairo_show_text(cr, txt)
    cairo_new_path(cr)
end

local function date_block(cr, cx, y)
    local t = os.date('*t')
    centered(cr, DNI[t.wday], cx, y, 24, '00FF88')
    centered(cr, string.format('%d %s %d', t.day, MIES[t.month], t.year), cx, y + 28, 17, 'FFFFFF')
end

-- pierścień-wskaźnik (CPU, RAM)
local function ring(cr, cx, cy, r, w, frac, col, label, valtxt)
    local a0 = 0.75 * PI
    local a1 = 2.25 * PI
    cairo_new_path(cr)
    cairo_set_line_width(cr, w)
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
    -- tło
    cairo_set_source_rgba(cr, rgba('FFFFFF', 0.12))
    cairo_arc(cr, cx, cy, r, a0, a1)
    cairo_stroke(cr)
    -- wartość
    cairo_new_path(cr)
    cairo_set_source_rgba(cr, rgba(col, 0.95))
    cairo_arc(cr, cx, cy, r, a0, a0 + (a1 - a0) * math.min(frac, 1))
    cairo_stroke(cr)
    -- tekst
    cairo_select_font_face(cr, 'Monaspace Krypton Frozen', CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_source_rgba(cr, rgba('FFFFFF', 1))
    cairo_set_font_size(cr, 16)
    local e = cairo_text_extents_t:create()
    cairo_text_extents(cr, valtxt, e)
    cairo_move_to(cr, cx - e.width/2 - e.x_bearing, cy + 4)
    cairo_show_text(cr, valtxt)
    cairo_set_font_size(cr, 11)
    cairo_set_source_rgba(cr, rgba(col, 1))
    cairo_text_extents(cr, label, e)
    cairo_move_to(cr, cx - e.width/2 - e.x_bearing, cy + r + 20)
    cairo_show_text(cr, label)
    cairo_new_path(cr)
end

-- zegar analogowy
local function clock(cr, cx, cy, r)
    local t = os.date('*t')
    local sec, min, hr = t.sec, t.min + t.sec/60, (t.hour % 12) + t.min/60

    -- tarcza
    cairo_set_source_rgba(cr, rgba('000000', 0.35))
    cairo_arc(cr, cx, cy, r, 0, 2*PI)
    cairo_fill(cr)
    cairo_set_source_rgba(cr, rgba('00FF88', 0.9))
    cairo_set_line_width(cr, 3)
    cairo_arc(cr, cx, cy, r, 0, 2*PI)
    cairo_stroke(cr)

    -- kreski godzin
    for i = 0, 11 do
        local a = i * PI/6 - PI/2
        local r1 = (i % 3 == 0) and r - 14 or r - 9
        cairo_set_line_width(cr, (i % 3 == 0) and 3 or 1.5)
        cairo_set_source_rgba(cr, rgba('FFFFFF', 0.9))
        cairo_move_to(cr, cx + r1*math.cos(a), cy + r1*math.sin(a))
        cairo_line_to(cr, cx + (r-4)*math.cos(a), cy + (r-4)*math.sin(a))
        cairo_stroke(cr)
    end

    local function hand(angle, len, width, col)
        local a = angle - PI/2
        cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
        cairo_set_line_width(cr, width)
        cairo_set_source_rgba(cr, rgba(col, 1))
        cairo_move_to(cr, cx - 0.15*len*math.cos(a), cy - 0.15*len*math.sin(a))
        cairo_line_to(cr, cx + len*math.cos(a), cy + len*math.sin(a))
        cairo_stroke(cr)
    end
    hand(hr  * PI/6,  r*0.5,  5, 'FFFFFF')
    hand(min * PI/30, r*0.75, 3, 'FFFFFF')
    hand(sec * PI/30, r*0.85, 1.5, '00FF88')

    cairo_set_source_rgba(cr, rgba('00FF88', 1))
    cairo_arc(cr, cx, cy, 4, 0, 2*PI)
    cairo_fill(cr)
    cairo_new_path(cr)
end

local GPU_MODE = 'amd'
local mode_file = io.open(os.getenv('HOME') .. '/.config/conky/gpu-mode', 'r')
if mode_file then
    GPU_MODE = mode_file:read('*l') or GPU_MODE
    mode_file:close()
end

local function drm_gpu_usage()
    for i = 0, 15 do
        local path = string.format('/sys/class/drm/card%d/device/gpu_busy_percent', i)
        local file = io.open(path, 'r')
        if file then
            local usage = tonumber(file:read('*l'))
            file:close()
            if usage then return math.min(usage, 100) end
        end
    end
    return nil
end

local engine_paths = {}
if GPU_MODE == 'intel' then
    local pipe = io.popen(
        "for f in /sys/class/drm/card*/device/engine/*/busy /sys/class/drm/card*/device/gt/gt*/engine/*/busy; do " ..
        "[ -r \"$f\" ] && printf '%s\\n' \"$f\"; done 2>/dev/null"
    )
    if pipe then
        for path in pipe:lines() do
            engine_paths[#engine_paths + 1] = path
        end
        pipe:close()
    end
end

local previous_engine_busy
local previous_engine_time

local function intel_gpu_usage()
    local total = 0
    local count = 0
    for _, path in ipairs(engine_paths) do
        local file = io.open(path, 'r')
        if file then
            local value = tonumber(file:read('*l'))
            file:close()
            if value then
                total = total + value
                count = count + 1
            end
        end
    end
    if count == 0 then return drm_gpu_usage() end

    local now = os.time()
    local usage
    if previous_engine_busy and previous_engine_time and now > previous_engine_time then
        local elapsed_ns = (now - previous_engine_time) * 1000000000
        if total >= previous_engine_busy then
            usage = math.min((total - previous_engine_busy) / elapsed_ns * 100, 100)
        end
    end
    previous_engine_busy = total
    previous_engine_time = now
    return usage
end

local function nvidia_gpu_usage()
    local pipe = io.popen(
        'nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null'
    )
    if not pipe then return nil end
    local usage = tonumber(pipe:read('*l'))
    pipe:close()
    return usage and math.min(usage, 100) or nil
end

local function gpu_usage()
    if GPU_MODE == 'amd' then return drm_gpu_usage() end
    if GPU_MODE == 'intel' then return intel_gpu_usage() end
    if GPU_MODE == 'nvidia' then return nvidia_gpu_usage() end
    return nil
end

function conky_main()
    if conky_window == nil then return end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
        conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    local cpu = tonumber(conky_parse('${cpu}')) or 0
    local mem = tonumber(conky_parse('${memperc}')) or 0
    local gpu = gpu_usage()

    date_block(cr, 170, 30)
    clock(cr, 170, 170, 85)
    if GPU_MODE == 'none' then
        ring(cr, 110, 345, 40, 8, cpu/100, '00FF88', 'CPU', string.format('%d%%', cpu))
        ring(cr, 230, 345, 40, 8, mem/100, '00B7FF', 'RAM', string.format('%d%%', mem))
    else
        ring(cr, 55,  345, 40, 8, cpu/100, '00FF88', 'CPU', string.format('%d%%', cpu))
        ring(cr, 170, 345, 40, 8, (gpu or 0)/100, 'FF8800', 'GPU',
            gpu and string.format('%d%%', gpu) or 'N/A')
        ring(cr, 285, 345, 40, 8, mem/100, '00B7FF', 'RAM', string.format('%d%%', mem))
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
