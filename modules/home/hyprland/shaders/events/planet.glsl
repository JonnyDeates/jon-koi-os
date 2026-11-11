// Premultiplied planet colour in .rgb, coverage in .a; atmosphere glow is returned separately.
vec4 planet(vec2 uv, float seed, float slot, float lt, float t, float fade, out vec3 glowOut) {
    glowOut = vec3(0.0);
    vec2 rnd = hash22(vec2(slot * 1.7, seed + 3.0));
    // Mostly small-to-medium, occasionally huge.
    float radius = mix(0.05, 0.26, pow(hash12(vec2(slot, seed + 5.0)), 1.8));
    vec2 center = (rnd - 0.5) * 2.0 * halfExtent() * vec2(0.75, 0.6);
    center += (hash22(vec2(slot, seed + 9.0)) - 0.5) * 0.0006 * lt;

    bool gas = hash12(vec2(slot, seed + 13.0)) < 0.55; // otherwise rocky/icy
    bool ringed = hash12(vec2(slot, seed + 17.0)) < 0.4;
    float tilt = (hash12(vec2(slot, seed + 19.0)) - 0.5) * 0.9;
    float spin = mix(0.04, 0.12, hash12(vec2(slot, seed + 23.0)));
    // Sun off to one side; sometimes partly behind the planet for a backlit crescent.
    vec2 lightDir = normalize(hash22(vec2(slot, seed + 29.0)) - 0.5);
    vec3 light = normalize(vec3(lightDir, mix(-0.45, 0.45, hash12(vec2(slot, seed + 33.0)))));

    vec2 d = (uv - center) / radius;
    float r2 = dot(d, d);
    if (r2 > (ringed ? 5.0 : 2.8)) {
        return vec4(0.0);
    }
    float r = sqrt(r2);
    vec2 dt = rotate(tilt) * d;
    float px = 1.5 / (radius * minDim());

    // Two related colours from a random hue. Some gas giants are Jupiter-like tans and creams;
    // rocky worlds keep mostly blue oceans, and some are icy.
    float hueA = hash12(vec2(slot, seed + 31.0));
    vec3 palA = planetHue(hueA);
    vec3 palB = planetHue(fract(hueA + mix(0.12, 0.45, hash12(vec2(slot, seed + 37.0)))));
    float flavour = hash12(vec2(slot, seed + 41.0));
    if (gas && flavour < 0.35) {
        palA = mix(vec3(0.86, 0.7, 0.5), palA, 0.25);
    } else if (!gas) {
        palB = mix(vec3(0.15, 0.35, 0.7), palB, 0.35);
        if (flavour < 0.2) {
            palA = mix(vec3(0.9, 0.95, 1.0), palA, 0.2);
        }
    }
    vec2 texOff = hash22(vec2(slot, seed + 43.0)) * 100.0; // each planet gets its own surface
    // Rocky worlds get a blue sky; gas giants a pale haze in their own colours.
    vec3 sky = gas ? mix(palA, vec3(1.0, 0.9, 0.8), 0.45)
                   : mix(vec3(0.35, 0.62, 1.0), TEAL, hash12(vec2(slot, seed + 39.0)) * 0.5);
    const vec3 SUNSET = vec3(1.0, 0.5, 0.3);
    float thickness = gas ? 0.09 : 0.06;   // atmosphere height as a fraction of the radius
    float scaleH = thickness * 0.5;

    vec4 body = vec4(0.0);
    if (r < 1.0 + px) {
        float z = sqrt(max(1.0 - r2, 0.0));
        vec3 n = vec3(d, z);
        vec3 s = vec3(dt, z);
        float lon = atan(s.x, s.z) + t * spin;
        float lat = asin(clamp(s.y, -1.0, 1.0));
        float sunDot = dot(n, light);

        vec3 surf;
        float clouds = 0.0;
        float ocean = 0.0;
        if (gas) {
            float warp = fbm(vec2(lon * 1.5, lat * 8.0) + texOff) * 0.9;
            float bands = fbm(vec2(lat * 7.0 + warp, lon * 0.4) + texOff);
            // Mostly palA with softer palB bands and pale highlights, like a gas giant's belts.
            surf = mix(palA * 0.85, mix(palA, palB, 0.45), smoothstep(0.35, 0.65, bands));
            surf = mix(surf, vec3(1.0, 0.95, 0.9), smoothstep(0.62, 0.8, bands) * 0.35);
        } else {
            float land = fbm(vec2(lon, lat) * 2.2 + texOff);
            ocean = smoothstep(0.52, 0.46, land);
            surf = mix(palB * 0.45, palA * 0.8, 1.0 - ocean);
            surf = mix(surf, vec3(0.95), smoothstep(1.15, 1.45, abs(lat)) * 0.85);

            // Clouds drift a little faster than the ground and cast soft shadows on it.
            vec2 cp = vec2(lon + t * spin * 0.6, lat * 2.2) + texOff.yx;
            float cw = fbm(cp * 1.8) * 1.2;
            clouds = smoothstep(0.5, 0.75, fbm(cp * 2.4 + cw));
            float shadowC = smoothstep(0.5, 0.75, fbm((cp - light.xy * 0.05) * 2.4 + cw));
            surf *= 1.0 - 0.35 * shadowC;
        }

        float diff = clamp((sunDot + 0.05) / 1.05, 0.0, 1.0);
        vec3 col = surf * (0.015 + diff);
        if (!gas) {
            // Sun glint on the oceans, and lit clouds on top.
            float spec = pow(max(dot(reflect(-light, n), vec3(0.0, 0.0, 1.0)), 0.0), 40.0);
            col += vec3(1.0, 0.95, 0.85) * spec * ocean * (1.0 - clouds) * 0.6;
            col = mix(col, vec3(0.95, 0.97, 1.0) * (0.02 + diff), clouds * 0.9);
        }

        // Haze thickens toward the limb (more air along the line of sight) and softens the surface.
        float airmass = thickness / max(z, 0.04);
        float haze = 1.0 - exp(-airmass * 6.0);
        vec3 hazeLight = mix(SUNSET, sky, smoothstep(-0.05, 0.4, sunDot)) * smoothstep(-0.25, 0.3, sunDot);
        col = mix(col, hazeLight * 0.8, haze * 0.75);

        // Twilight: a thin band of scattered sunset light along the day/night line, strongest near
        // the limb where the light crosses the most air.
        float twilight = exp(-sunDot * sunDot / 0.006) * smoothstep(-0.15, 0.03, sunDot);
        col += SUNSET * twilight * (0.04 + 0.3 * haze);

        float cover = smoothstep(1.0 + px, 1.0 - px, r);
        body = vec4(col * cover, cover);
    }

    // Atmosphere seen edge-on beyond the surface: a thin, bright shell that fades out into space.
    if (r > 1.0 - px) {
        vec3 limbN = vec3(d / r, 0.0);
        float limbSun = dot(limbN, light);
        float density = exp(-max(r - 1.0, 0.0) / scaleH);
        // Light passes the long way through the shell at the edge.
        float column = density * sqrt(max(r - 1.0, 0.0) + scaleH) / sqrt(scaleH);
        float lit = smoothstep(-0.35, 0.5, limbSun);
        // Backlit: sunlight scattering forward through the rim makes a ring of light.
        float forward = pow(max(-light.z, 0.0), 1.2) * smoothstep(-1.0, 0.2, limbSun) * 2.0;
        vec3 tint = mix(SUNSET, sky, smoothstep(-0.1, 0.45, limbSun));
        float edgeIn = smoothstep(1.0 - px, 1.0 + px, r);
        glowOut = tint * column * (lit + forward) * 0.75 * edgeIn * fade;
    }

    if (ringed) {
        vec2 e = vec2(dt.x, dt.y / 0.28);
        float er = length(e);
        float band = smoothstep(1.35, 1.42, er) * smoothstep(2.15, 2.05, er);
        if (band > 0.0) {
            float stripes = 0.55 + 0.45 * sin(er * 38.0) * sin(er * 11.0 + 1.0);
            float shade = 0.35 + 0.65 * clamp(dot(normalize(vec3(e.x, 0.0, e.y)), light) * 0.5 + 0.6, 0.0, 1.0);
            vec4 ring = vec4(mix(palA, vec3(0.9, 0.85, 0.75), 0.5) * shade, band * stripes * 0.75);
            ring.rgb *= ring.a;
            if (dt.y < 0.0) {
                body = ring + body * (1.0 - ring.a);
            } else {
                body = body + ring * (1.0 - body.a);
            }
        }
    }
    return body * fade;
}
