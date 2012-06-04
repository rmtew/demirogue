-- This is a modified version of the 'Simple Lua Preprocessor' at http://lua-users.org/wiki/SimpleLuaPreprocessor
function expand( src, args )
    local parts = {
        'local _parts = {}\n',
        'local function _write( str ) _parts[#_parts+1] = str end\n'
    }

    for name, value in pairs(args) do
        assert(type(name) == 'string')
        assert(name ~= '_parts' and name ~= '_write')

        parts[#parts+1] = string.format('local %s = %s\n', name, tostring(value))
    end

    local final = 1
    for text, code, index in src:gmatch('(.-)([#$]%b())()') do
        final = index
        if text ~= '' then
            parts[#parts+1] = string.format('_write(%q)\n', text)
        end

        if code ~= '' then
            if code:sub(1, 1) == '#' then
                parts[#parts+1] = string.format('%s\n', code:sub(3, -2))
            else
                parts[#parts+1] = string.format('_write(tostring(%s))\n', code:sub(3, -2))
            end
        end
    end

    parts[#parts+1] = string.format('_write(%q)\n', src:sub(final))

    parts[#parts+1] = 'return table.concat(_parts)'

    local compiledsrc = table.concat(parts)

    -- print(compiledsrc)

    local func, msg = loadstring(compiledsrc, 'expand')

    if not func then
        error(msg)
    end

    return func()
end

if false then
    local src = [[
            extern vec2 point1s[$(NUMLINES)];
            extern vec2 norms[$(NUMLINES)];
            extern float lengths[$(NUMLINES)];
            extern float width;

            float metaline(vec2 pc, vec2 point1, vec2 norm, float len, vec2 valence)
            {
                vec2 disp = pc - point1;
                float lambda = dot(disp, norm);
                lambda = clamp(lambda, 0, len);

                vec2 proj = point1 + (norm * lambda);
                vec2 dispnear = pc - proj;
                float d = length(dispnear);           // distance from the line
                float invd = width - d;               // inverse distance
                float invdc = step(0, invd) * invd;   // inverse distance clamped >= 0
                float invdcn = invdc / width;         // inverse distance clamped and normalised

                // n^3 seems to look the best
                return invdcn * invdcn * invdcn;
            }

            vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
            {
                float p = 0.0;
                
                #(for i = 1, NUMLINES do)
                p += metaline(pc, point1s[$(i)], norms[$(i)], lengths[$(i)], valences[$(i)]);
                #(end)

                return vec4(p, p, p, 1);
            }
    ]]

    local test = expand(src, { NUMLINES = 4 })
    print(test)
end