// Animated space wallpaper for shaderbg (Shadertoy-style mainImage; iTime/iResolution come from shaderbg).
// iResolution is in physical pixels (shaderbg is patched to render at the output's scale).

const vec3 KOI_BLUE = vec3(0.482, 0.788, 1.000);
const vec3 ROSE = vec3(0.922, 0.435, 0.573);
const vec3 TEAL = vec3(0.612, 0.812, 0.847);
const vec3 VIOLET = vec3(0.55, 0.28, 0.85);

// Events: each monitor rolls once per period for a black hole, a planet, or nothing.
// The event fades in, drifts, then fades out before the next roll.
const float EVENT_PERIOD = 150.0;
const float EVENT_FADE = 20.0;
const float BLACKHOLE_CHANCE = 0.15;
const float STAR_CHANCE = 0.12;
const float SYSTEM_CHANCE = 0.12;
const float COMET_CHANCE = 0.10;
const float FIELD_CHANCE = 0.10;
const float PLANET_CHANCE = 0.25;

// Sizes are measured against the screen's short side, so portrait and landscape screens match.
float minDim() {
    return min(iResolution.x, iResolution.y);
}

// Physical pixels per 1440p pixel, so pixel-sized details look the same on 1440p and 4K screens.
float pxScale() {
    return minDim() / 1440.0;
}

vec2 halfExtent() {
    return 0.5 * iResolution.xy / minDim();
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
               mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 hash33(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx);
}

// Distances to the nearest and second-nearest of a set of slowly wandering 3D cell points.
vec2 voronoi3(vec3 p, float t) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    float f1 = 8.0;
    float f2 = 8.0;
    for (int z = -1; z <= 1; z++) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec3 g = vec3(x, y, z);
                vec3 h = hash33(i + g);
                vec3 o = 0.5 + 0.35 * sin(t * 0.4 + h * 6.2831);
                float dd = length(g + o - f);
                if (dd < f1) {
                    f2 = f1;
                    f1 = dd;
                } else if (dd < f2) {
                    f2 = dd;
                }
            }
        }
    }
    return vec2(f1, f2);
}

float fbm(vec2 p) {
    const mat2 rot = mat2(0.8, -0.6, 0.6, 0.8);
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = rot * p * 2.0 + 17.0;
        a *= 0.5;
    }
    return v;
}

// fbm that fades out octaves finer than the pixel footprint fp (in p units), so detail too small
// to display turns into smooth average instead of speckle.
float fbmAA(vec2 p, float fp) {
    const mat2 rot = mat2(0.8, -0.6, 0.6, 0.8);
    float v = 0.0;
    float a = 0.5;
    float f = 1.0;
    for (int i = 0; i < 5; i++) {
        float keep = clamp(1.5 - fp * f * 3.0, 0.0, 1.0);
        v += a * mix(0.5, noise(p), keep);
        p = rot * p * 2.0 + 17.0;
        a *= 0.5;
        f *= 2.0;
    }
    return v;
}

mat2 rotate(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(c, s, -s, c);
}

// 0 = cool red/orange, 0.5 = yellow-white, 1 = hot blue-white.
vec3 starColor(float k) {
    vec3 cool = vec3(1.0, 0.45, 0.18);
    vec3 mid = vec3(1.0, 0.93, 0.82);
    vec3 hot = vec3(0.62, 0.76, 1.0);
    return k < 0.5 ? mix(cool, mid, k * 2.0) : mix(mid, hot, (k - 0.5) * 2.0);
}

// Returns the nebula colour; dens is its density, used to dim stars behind thick clouds.
vec3 nebula(vec2 uv, vec2 seed, float t, out float dens) {
    vec2 p = uv * 1.4 + seed * 7.0;
    float nt = t * 0.012;
    vec2 q = vec2(fbm(p + vec2(0.0, nt)), fbm(p + vec2(5.2, 1.3) - nt));
    vec2 r = vec2(fbm(p + 3.0 * q + vec2(1.7, 9.2) + nt * 0.6),
                  fbm(p + 3.0 * q + vec2(8.3, 2.8) - nt * 0.6));
    float n = fbm(p + 3.0 * r);

    // Large-scale mask so nebulas form distinct clouds with empty space between them.
    float mask = smoothstep(0.38, 0.72, noise(p * 0.45 + seed * 3.0 + nt * 0.3));
    dens = smoothstep(0.38, 0.95, n) * mask;

    vec3 c = mix(ROSE, KOI_BLUE, clamp(q.x * 1.7 - 0.35, 0.0, 1.0));
    c = mix(c, TEAL, clamp(r.y * 1.5 - 0.6, 0.0, 1.0));
    c = mix(c, VIOLET, clamp(r.x * 1.3 - 0.7, 0.0, 1.0));
    // Push saturation so the clouds read as colour rather than grey haze.
    c = mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, 1.6);
    vec3 col = c * dens * 0.55 + c * pow(dens, 2.5) * 0.9 + vec3(1.0, 0.9, 0.95) * pow(dens, 6.0) * 0.35;

    float dust = smoothstep(0.55, 0.80, fbm(p * 2.3 + r * 1.5 - nt));
    return col * (1.0 - dust * 0.6);
}

// One small star per occupied grid cell. lens > 1 where a black hole squeezes the sky: stars keep
// their on-screen size and fade so the squeezed region doesn't turn into speckle.
vec3 starLayer(vec2 uv, float cells, float density, float brightness, float seed, float t, float lens) {
    vec2 g = uv * cells;
    vec2 id = floor(g);
    float h = hash12(id + seed);
    if (h > density) {
        return vec3(0.0);
    }
    float cellPx = minDim() / cells / lens;
    vec2 pos = 0.5 + (hash22(id + seed) - 0.5) * 0.6;
    float dPx = length(fract(g) - pos) * cellPx;

    float radius = mix(0.6, 1.5, hash12(id + seed + 3.1)) * pxScale();
    float core = exp(-dPx * dPx / (radius * radius));
    float glow = exp(-dPx / (radius * 2.5)) * 0.10;

    float twinkle = 0.65 + 0.35 * sin(t * mix(0.4, 2.2, hash12(id + seed + 7.7)) + h * 6.2831);
    vec3 tint = mix(starColor(hash12(id + seed + 11.3)), vec3(1.0), 0.55);
    return tint * (core + glow) * twinkle * brightness / (lens * lens);
}

// A few big, hot stars with a pulsing, shimmering corona and diffraction spikes.
vec3 heatStars(vec2 uv, float seed, float t, float lens) {
    const float cells = 3.0;
    vec2 g = uv * cells;
    vec2 base = floor(g);
    vec3 acc = vec3(0.0);
    float ps = pxScale();
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 id = base + vec2(x, y);
            float h = hash12(id + seed + 200.0);
            if (h > 0.30) {
                continue;
            }
            vec2 pos = id + 0.5 + (hash22(id + seed + 200.0) - 0.5) * 0.7;
            vec2 dv = (g - pos) / cells * minDim() / lens; // offset in screen pixels
            float dPx = length(dv);

            vec3 col = starColor(hash12(id + seed + 5.0));
            float size = mix(2.0, 4.5, hash12(id + seed + 9.0)) * ps;
            float pulse = 0.82 + 0.18 * sin(t * mix(0.5, 1.3, h * 3.3) + h * 40.0);

            // Heat shimmer: ripples that travel outward through the corona.
            vec2 dir = dv / max(dPx, 1e-3);
            float shimmer = noise(dir * 3.0 + vec2(dPx / ps * 0.04 - t * 0.9) + id * 13.0);

            float core = exp(-dPx * dPx / (size * size));
            float corona = exp(-dPx / (size * 9.0 * (0.7 + 0.6 * shimmer))) * 0.65 * pulse;
            float halo = exp(-dPx / (size * 25.0)) * 0.12 * pulse;

            // Gaussian falloff keeps the spikes short instead of trailing faint lines across the screen.
            vec2 a = abs(dv);
            float spikeW = 1.1 * ps;
            float spikeLen = size * 14.0 * pulse;
            vec2 along = a / spikeLen;
            float spikes = exp(-a.x / spikeW) * exp(-along.y * along.y) + exp(-a.y / spikeW) * exp(-along.x * along.x);

            acc += col * (corona + halo) + mix(col, vec3(1.0), 0.7) * (core * 1.6 + spikes * 0.45 * pulse);
        }
    }
    return acc / (lens * lens);
}

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

    vec3 palA = mix(ROSE, vec3(0.85, 0.62, 0.40), hash12(vec2(slot, seed + 31.0)));
    vec3 palB = mix(KOI_BLUE, TEAL, hash12(vec2(slot, seed + 37.0)));
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
            float warp = fbm(vec2(lon * 1.5, lat * 8.0)) * 0.9;
            float bands = fbm(vec2(lat * 7.0 + warp, lon * 0.4));
            // Mostly palA with softer palB bands and pale highlights, like a gas giant's belts.
            surf = mix(palA * 0.85, mix(palA, palB, 0.45), smoothstep(0.35, 0.65, bands));
            surf = mix(surf, vec3(1.0, 0.95, 0.9), smoothstep(0.62, 0.8, bands) * 0.35);
        } else {
            float land = fbm(vec2(lon, lat) * 2.2);
            ocean = smoothstep(0.52, 0.46, land);
            surf = mix(palB * 0.45, palA * 0.8, 1.0 - ocean);
            surf = mix(surf, vec3(0.95), smoothstep(1.15, 1.45, abs(lat)) * 0.85);

            // Clouds drift a little faster than the ground and cast soft shadows on it.
            vec2 cp = vec2(lon + t * spin * 0.6, lat * 2.2);
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

// Star kinds: < 0.4 a yellow sun like ours, < 0.7 a red giant, otherwise a blue-white star.
const float STAR_GIANT = 0.4;
const float STAR_BLUE = 0.7;

// A star with boiling plasma, granulation, limb darkening, sunspots, prominences and a corona of
// heat streaming outward. Returns premultiplied colour/coverage for the disk; corona light goes
// to glowOut, and shimmer is how strongly the heat should ripple the sky behind it.
vec4 star(vec2 uv, vec2 center, float radius, float kind, float seed, float slot, float t, float fade,
          out vec3 glowOut, out float shimmer) {
    glowOut = vec3(0.0);
    shimmer = 0.0;
    bool giant = kind >= STAR_GIANT && kind < STAR_BLUE;
    bool blue = kind >= STAR_BLUE;

    vec3 coreCol = giant ? vec3(1.35, 0.48, 0.1) : blue ? vec3(0.9, 1.1, 1.55) : vec3(1.45, 1.0, 0.4);
    vec3 limbCol = giant ? vec3(0.6, 0.08, 0.01) : blue ? vec3(0.35, 0.55, 1.3) : vec3(1.0, 0.33, 0.04);
    vec3 coronaCol = giant ? vec3(1.0, 0.35, 0.1) : blue ? vec3(0.55, 0.75, 1.4) : vec3(1.0, 0.72, 0.38);
    vec3 promCol = blue ? vec3(0.8, 0.9, 1.5) : vec3(1.0, 0.35, 0.3);
    float limbDark = giant ? 0.85 : blue ? 0.45 : 0.65;
    float cellScale = giant ? 10.0 : blue ? 18.0 : 22.0; // giants have huge convection cells
    float plasmaScale = giant ? 2.0 : blue ? 2.5 : 3.0;

    vec2 d = (uv - center) / radius;
    float r = length(d);
    if (r > 4.0) {
        return vec4(0.0);
    }
    vec2 dir = d / max(r, 1e-4);
    float px = 1.5 / (radius * minDim());

    // The surface boils, so the edge isn't perfectly round.
    float edge = 1.0 + (noise(dir * 4.0 + t * 0.15) - 0.5) * 0.006;
    vec4 body = vec4(0.0);
    if (r < edge + px) {
        float z = sqrt(max(1.0 - r * r, 0.0));
        float rot = t * 0.01;
        vec3 sp = vec3(d.x * cos(rot) + z * sin(rot), d.y, -d.x * sin(rot) + z * cos(rot));

        // Boiling plasma: slowly churning domain-warped noise dominates the look...
        vec2 ps = sp.xy * plasmaScale + sp.z * 1.7;
        vec2 q = vec2(fbm(ps + vec2(0.0, t * 0.02)), fbm(ps + vec2(5.2, 1.3) - t * 0.02));
        float plasma = fbm(ps * 1.4 + q * 2.5 + vec2(sp.z * 2.0, t * 0.03));
        // ...with faint granulation (convection cells and darker lanes) on top.
        vec2 v = voronoi3(sp * cellScale, t);
        float gran = smoothstep(0.0, 0.3, v.y - v.x);
        // Bright, thin plasma filaments threading through the surface.
        float fil = 1.0 - abs(2.0 * fbm(ps * 2.2 + q * 3.0 - vec2(t * 0.04, 0.0)) - 1.0);
        float b = 0.5 + 0.8 * plasma * plasma + 0.35 * pow(fil, 4.0) + (giant ? 0.08 : 0.15) * (gran - 0.5);
        if (!blue) {
            // Sunspots: a few small dark umbras with lighter penumbras.
            float spots = fbm(sp.xz * 3.5 + sp.y * 4.0 + seed + slot);
            b *= mix(1.0, 0.15, smoothstep(0.77, 0.82, spots));
            b *= mix(1.0, 0.6, smoothstep(0.73, 0.77, spots));
        }

        // Limb darkening: the edge is dimmer and redder because we see cooler, higher layers there.
        float limb = 1.0 - limbDark * (1.0 - pow(z, 0.6));
        vec3 col = mix(limbCol, coreCol, pow(z, 0.7)) * b * limb;
        // Glow from the hot corona spilling over the edge.
        col += coronaCol * exp(-(1.0 - r) / 0.04) * 0.35;
        float cover = smoothstep(edge + px, edge - px, r);
        body = vec4(col * cover, cover);
    }

    if (r > 0.98) {
        float h = max(r - 1.0, 0.0);
        // Streamers: tongues of hot gas reaching straight out, slowly changing shape...
        float streamer = fbm(dir * 6.0 + vec2(t * 0.02, -t * 0.015) + seed);
        float fine = fbm(dir * 18.0 + vec2(-t * 0.03, t * 0.02) + seed * 2.0);
        float reach = 0.04 + 0.32 * streamer * streamer + 0.06 * fine;
        // ...with waves of heat rippling outward through them.
        float waves = 0.75 + 0.25 * noise(vec2(h * 18.0 - t * 1.4, dot(dir, vec2(3.1, 1.7)) * 3.0));
        float tongues = exp(-h / reach) * waves;
        float corona = exp(-h / 0.03) * 0.8 + exp(-h / 0.4) * 0.22 + exp(-h / 1.5) * 0.07;
        vec3 g = coronaCol * (corona + tongues * 0.9);

        // Prominences: glowing arcs of plasma looping off the edge.
        for (int k = 0; k < 3; k++) {
            float hk = hash12(vec2(slot * 5.0 + float(k), seed + 81.0));
            if (hk > (giant ? 0.85 : 0.65)) {
                continue;
            }
            float ang = hk * 40.0 + float(k) * 2.1 + t * 0.003;
            vec2 at = vec2(cos(ang), sin(ang));
            vec2 tng = vec2(-at.y, at.x);
            vec2 q = vec2(dot(d - at, tng), dot(d - at, at));
            // Wobble the arc so it's an irregular plume rather than a perfect ring.
            q += (vec2(noise(q * 8.0 + t * 0.1), noise(q * 8.0 + 5.0 - t * 0.1)) - 0.5) * 0.05;
            float loopR = mix(0.08, 0.2, hash12(vec2(hk, 3.0))) * (0.9 + 0.1 * sin(t * 0.2 + hk * 9.0));
            float dist = abs(length(q * vec2(1.0, 0.8)) - loopR);
            float wisp = 0.4 + 0.6 * fbm(q * 14.0 + vec2(0.0, -t * 0.3));
            float width = 0.012 + 0.022 * wisp;
            float topFade = 1.0 - 0.55 * clamp(q.y / loopR, 0.0, 1.0); // brightest near the footpoints
            g += promCol * exp(-dist / width) * step(0.0, q.y) * wisp * wisp * topFade * 1.3;
        }
        glowOut = g * smoothstep(1.0 - px, 1.0 + px, r) * fade;
        shimmer = exp(-h * 2.5) * fade;
    }
    return body * fade;
}

// "front over back" for premultiplied colours.
vec4 over(vec4 front, vec4 back) {
    return front + back * (1.0 - front.a);
}

// A small planet lit by a star in direction toStar (view space, z toward the camera), with a thin
// atmosphere. Premultiplied colour/coverage; the atmosphere glow is folded into .rgb.
vec4 miniPlanet(vec2 uv, vec2 c, float rad, vec3 toStar, float t, float pseed) {
    vec2 d = (uv - c) / rad;
    float r2 = dot(d, d);
    if (r2 > 2.5) {
        return vec4(0.0);
    }
    float r = sqrt(r2);
    float px = 1.5 / (rad * minDim());
    vec3 L = normalize(toStar);
    bool gas = hash12(vec2(pseed, 1.0)) < 0.45;
    vec3 palA = mix(ROSE, vec3(0.85, 0.62, 0.40), hash12(vec2(pseed, 2.0)));
    vec3 palB = mix(KOI_BLUE, TEAL, hash12(vec2(pseed, 3.0)));
    vec3 sky = gas ? mix(palA, vec3(1.0, 0.9, 0.8), 0.45) : mix(vec3(0.35, 0.62, 1.0), TEAL, 0.3);

    vec4 body = vec4(0.0);
    if (r < 1.0 + px) {
        float z = sqrt(max(1.0 - r2, 0.0));
        vec3 n = vec3(d, z);
        float lon = atan(n.x, n.z) + t * 0.1;
        float lat = asin(clamp(n.y, -1.0, 1.0));
        vec3 surf;
        if (gas) {
            float bands = fbm(vec2(lat * 6.0 + fbm(vec2(lon, lat * 6.0)) * 0.8, lon * 0.4) + pseed);
            surf = mix(palA * 0.85, mix(palA, palB, 0.45), smoothstep(0.35, 0.65, bands));
        } else {
            float land = fbm(vec2(lon, lat) * 2.0 + pseed);
            surf = mix(palB * 0.5, palA * 0.8, smoothstep(0.45, 0.55, land));
        }
        float sunDot = dot(n, L);
        vec3 col = surf * (0.015 + clamp((sunDot + 0.05) / 1.05, 0.0, 1.0));
        float haze = 1.0 - exp(-0.06 / max(z, 0.04) * 6.0);
        col = mix(col, sky * 0.8 * smoothstep(-0.25, 0.3, sunDot), haze * 0.6);
        float cover = smoothstep(1.0 + px, 1.0 - px, r);
        body = vec4(col * cover, cover);
    }
    if (r > 1.0 - px) {
        float limbSun = dot(vec3(d / r, 0.0), L);
        float density = exp(-max(r - 1.0, 0.0) / 0.04);
        float forward = pow(max(-L.z, 0.0), 1.2) * smoothstep(-1.0, 0.2, limbSun) * 2.0;
        body.rgb += sky * density * (smoothstep(-0.35, 0.5, limbSun) + forward) * 0.6
                * smoothstep(1.0 - px, 1.0 + px, r);
    }
    return body;
}

// A star with planets on visible orbits. Inner planets orbit faster (Kepler's third law), each is
// lit by the star, and they pass behind it on the far side of their orbits and in front of it on
// the near side. Sometimes there's an asteroid belt. Premultiplied colour/coverage; shimmer is the
// star's heat ripple. Must be called from uniform control flow (orbit lines use derivatives).
vec4 solarSystem(vec2 uv, float seed, float slot, float t, float fade, out float shimmer) {
    vec2 center = (hash22(vec2(slot * 4.3, seed + 91.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.25, 0.2);
    float sysTilt = (hash12(vec2(slot, seed + 93.0)) - 0.5) * 0.5;
    float k = mix(0.22, 0.4, hash12(vec2(slot, seed + 95.0))); // how flattened the orbits look
    float depthK = sqrt(1.0 - k * k);
    float kind = hash12(vec2(slot, seed + 97.0)) * 0.85;     // mostly suns, sometimes giants or blue
    bool giant = kind >= STAR_GIANT && kind < STAR_BLUE;
    float starR = giant ? 0.07 : kind >= STAR_BLUE ? 0.03 : 0.045;
    int count = 3 + int(hash12(vec2(slot, seed + 99.0)) * 2.99); // 3-5 planets
    const float ORBIT_SPEED = 0.08; // innermost planet's angular speed, rad/s (~80 s per orbit)

    float aMax = halfExtent().x * 0.92;
    float a0 = max(starR * 2.6, aMax / pow(1.55, float(count - 1)));
    float spacing = pow(aMax / a0, 1.0 / float(count - 1));

    vec2 p = rotate(-sysTilt) * (uv - center); // into the orbit frame
    float er = length(vec2(p.x, p.y / k));     // radius within the orbital plane
    bool far = p.y > 0.0;                      // upper half of each ellipse is behind the star

    vec3 backLines = vec3(0.0);
    vec3 frontLines = vec3(0.0);
    vec4 backPlanets = vec4(0.0);
    vec4 frontPlanets = vec4(0.0);
    const vec3 LINE_COL = vec3(0.55, 0.65, 0.85);

    for (int i = 0; i < 7; i++) {
        float a = a0 * pow(spacing, float(i));
        float f = er - a;
        float w = max(fwidth(f), 1e-5) * 1.2;
        if (i >= count) {
            continue;
        }
        vec3 line = LINE_COL * exp(-(f * f) / (w * w)) * 0.10;
        if (far) {
            backLines += line;
        } else {
            frontLines += line;
        }

        float h = hash12(vec2(slot * 7.0 + float(i), seed + 101.0));
        float theta = h * 6.2831 + ORBIT_SPEED * pow(a0 / a, 1.5) * t;
        vec2 o = a * vec2(cos(theta), sin(theta));
        vec2 pc = center + rotate(sysTilt) * vec2(o.x, o.y * k);
        float prad = mix(0.008, 0.026, pow(hash12(vec2(h, 5.0)), 1.5));
        vec3 rel = vec3(pc - center, -o.y * depthK); // view space; far side of the orbit is away from us
        vec4 pl = miniPlanet(uv, pc, prad, -rel, t, h * 97.0);
        if (o.y > 0.0) {
            backPlanets = over(pl, backPlanets);
        } else {
            frontPlanets = over(pl, frontPlanets);
        }
    }

    // Asteroid belt in a gap between two orbits: tiny specks drifting around the star.
    if (hash12(vec2(slot, seed + 103.0)) < 0.65) {
        float ab = a0 * pow(spacing, 1.5 + floor(hash12(vec2(slot, seed + 105.0)) * float(count - 3)));
        float band = exp(-pow((er - ab) / (ab * 0.08), 2.0));
        if (band > 0.01) {
            vec2 q = rotate(ORBIT_SPEED * pow(a0 / ab, 1.5) * t) * vec2(p.x, p.y / k);
            const float cell = 0.004;
            vec2 id = floor(q / cell);
            vec2 jit = hash22(id + seed);
            float dPx = length(fract(q / cell) - (0.2 + 0.6 * jit)) * cell * minDim();
            float speck = exp(-dPx * dPx / (0.8 * pxScale())) * step(hash12(id + seed + 7.0), 0.35);
            vec3 rock = vec3(0.75, 0.68, 0.6) * speck * band * 1.3;
            if (far) {
                backLines += rock;
            } else {
                frontLines += rock;
            }
        }
    }

    vec3 starGlow;
    vec4 sun = star(uv, center, starR, kind, seed, slot, t, 1.0, starGlow, shimmer);
    shimmer *= fade;

    vec4 ovl = over(backPlanets, vec4(backLines, 0.0));
    ovl = over(sun, ovl);
    ovl = over(vec4(starGlow, 0.0), ovl);
    ovl = over(vec4(frontLines, 0.0), ovl);
    ovl = over(frontPlanets, ovl);
    return ovl * fade;
}

// A comet crossing the screen: a bright nucleus in a glowing green-blue coma, a straight blue ion
// tail with streamers rushing outward, and a broad, curved dust tail. Both tails point away from
// the (off-screen) sun rather than along the direction of travel. Returns additive light.
vec3 comet(vec2 uv, float seed, float slot, float lt, float t, float fade) {
    float sunAng = hash12(vec2(slot, seed + 111.0)) * 6.2831;
    vec2 tailDir = vec2(cos(sunAng), sin(sunAng));
    float side = hash12(vec2(slot, seed + 113.0)) < 0.5 ? -1.0 : 1.0;
    vec2 travel = rotate(side * mix(1.1, 1.9, hash12(vec2(slot, seed + 115.0)))) * tailDir;
    float scale = mix(0.6, 1.5, hash12(vec2(slot, seed + 117.0)));
    vec2 start = (hash22(vec2(slot * 5.7, seed + 119.0)) - 0.5) * 2.0 * halfExtent() * 0.6 - travel * 0.35;
    vec2 nucleus = start + travel * 0.7 * (lt / EVENT_PERIOD);

    // x runs down the tail (away from the sun), y across it.
    vec2 rel = uv - nucleus;
    vec2 q = vec2(dot(rel, tailDir), dot(rel, vec2(-tailDir.y, tailDir.x))) / scale;
    float r = length(q);
    float core = 1.5 * pxScale() / minDim() / scale;

    vec3 col = vec3(1.0) * exp(-r * r / (core * core)) * 1.5;
    col += vec3(0.6, 1.0, 0.85) * exp(-r / 0.006) * 0.9;
    col += vec3(0.5, 0.85, 0.9) * exp(-r / 0.03) * 0.25;

    float x = max(q.x, 0.0);
    float on = smoothstep(-0.01, 0.02, q.x);
    // Ion tail: straight, narrow and blue, with streamers rushing outward and a gentle ripple.
    float yi = q.y - sin(q.x * 6.0 - t * 0.6) * q.x * 0.012;
    float wi = 0.003 + x * 0.04;
    float streak = 0.55 + 0.45 * noise(vec2(yi / wi * 2.5, q.x * 6.0 - t * 0.9));
    col += vec3(0.45, 0.7, 1.25) * exp(-abs(yi) / wi) * exp(-x / 0.55) * streak * on * 0.9;
    // Dust tail: broad and pale gold, curving back behind the comet's motion, with faint striations.
    float yd = q.y + side * x * x * 0.6;
    float wd = 0.004 + x * 0.16;
    float stri = 0.8 + 0.2 * noise(vec2(q.x * 25.0, yd / wd * 1.5 + 3.0));
    col += vec3(1.0, 0.88, 0.65) * exp(-(yd / wd) * (yd / wd)) * exp(-x / 0.45) * stri * on * 0.55;
    return col * fade;
}

// A field of tumbling asteroids drifting past at four depths (near ones bigger and faster, far ones
// fading into dusty haze), lit from one side, with fine dust streaming past. Premultiplied
// colour/coverage.
vec4 asteroidField(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 flow = normalize(hash22(vec2(slot, seed + 121.0)) - 0.5);
    vec3 L = normalize(vec3(normalize(hash22(vec2(slot, seed + 123.0)) - 0.5), 0.25));
    vec4 ov = vec4(0.0);
    for (int i = 0; i < 4; i++) {
        float depth = float(i) / 3.0; // 0 = far, 1 = near
        float cell = mix(0.045, 0.3, depth * depth);
        vec2 g = (uv + flow * mix(0.002, 0.02, depth) * t + float(i) * 13.7) / cell;
        vec2 id = floor(g);
        float h = hash12(id + seed + float(i) * 31.0);
        if (h > mix(0.32, 0.22, depth)) {
            continue;
        }
        vec2 h2 = hash22(id + seed + float(i) * 17.0);
        // Mostly small rocks with the odd big one, placed anywhere they fit in their cell.
        float rad = mix(0.1, 0.28, pow(h2.x, 1.5));
        float maxJitter = 0.5 - rad * 1.35;
        vec2 pos = 0.5 + (hash22(id + seed + float(i) * 23.0) - 0.5) * 2.0 * maxJitter;
        vec2 q = (fract(g) - pos) / rad;
        // Elongated, lumpy rock that tumbles as it spins.
        float spinA = t * mix(-0.15, 0.15, h2.y);
        float stretch = mix(1.0, 1.7, hash12(id + seed + 5.0));
        vec2 rq = rotate(spinA) * q;
        vec2 sq = vec2(rq.x / stretch, rq.y);
        float r = length(sq);
        if (r > 1.5) {
            continue;
        }
        vec2 dir = sq / max(r, 1e-4);
        float edgeR = 1.0 + 0.45 * (noise(dir * 1.5 + h * 20.0) - 0.5) + 0.12 * (noise(dir * 5.0 + h * 9.0) - 0.5);
        float px = 1.5 / (rad * cell * minDim());
        float cover = smoothstep(edgeR + px, edgeR - px, r);
        if (cover <= 0.0) {
            continue;
        }
        // Bumpy, cratered surface: tilt the normal by the slope of a noise field.
        float bump = fbm(rq * 2.5 + h * 7.0);
        vec2 grad = vec2(fbm(rq * 2.5 + vec2(0.05, 0.0) + h * 7.0) - bump,
                         fbm(rq * 2.5 + vec2(0.0, 0.05) + h * 7.0) - bump) / 0.05;
        float nz = sqrt(max(1.0 - (r / edgeR) * (r / edgeR), 0.0));
        vec3 n = normalize(vec3(rotate(-spinA) * (sq / edgeR), nz) + vec3(rotate(-spinA) * grad, 0.0) * 0.2);
        float diff = clamp(dot(n, L), 0.0, 1.0);
        vec3 rockCol = mix(vec3(0.32, 0.29, 0.27), vec3(0.42, 0.34, 0.27), h2.y) * (0.55 + 0.7 * bump);
        vec3 col = rockCol * (0.008 + 1.2 * diff);
        col = mix(vec3(0.02, 0.025, 0.04), col, mix(0.25, 1.0, depth)); // distant rocks fade into haze
        ov = over(vec4(col * cover, cover), ov);
    }
    // Fine dust close to the camera, streaming past quickly.
    ov.rgb += starLayer(uv + flow * 0.04 * t, 90.0, 0.12, 0.5, seed + 9.0, t, 1.0) * vec3(0.9, 0.85, 0.8);
    return ov * fade;
}

const vec3 DISK_DUST = vec3(0.22, 0.08, 0.03);
const vec3 DISK_AMBER = vec3(0.95, 0.56, 0.30);
const vec3 DISK_WHITE = vec3(1.0, 0.95, 0.88);

// One rotation phase of the disk texture. fpRho/fpDir are pixel footprints in rho and direction
// units, used to drop detail that's too fine to display.
float diskLayer(float rho, vec2 dirp, float angle, float seed, float fpRho, float fpDir) {
    vec2 p = rotate(angle) * dirp;
    float warp = fbmAA(p * 1.2 + vec2(rho * 0.8) + seed, 1.2 * fpDir + 0.8 * fpRho);
    float streak = fbmAA(vec2(rho * 5.0 + warp * 4.0, seed) + p * 1.6, 5.0 * fpRho + 1.6 * fpDir);
    float clump = fbmAA(p * 2.5 + vec2(rho * 1.5 + warp * 2.0), 2.5 * fpDir + 1.5 * fpRho);
    return streak * 0.45 + clump * 0.7;
}

// Accretion disk material at radius rho (units of R) along in-plane direction dirp: turbulent,
// streaky gas that is white-hot inward, amber further out, with dark dusty lanes.
// Returns premultiplied emission in .rgb and opacity in .a.
vec4 diskSample(float rho, vec2 dirp, float t, float spinDir, float seed, float fpRho, float fpDir) {
    // Ragged outer edge so the disk trails off instead of ending in a clean ellipse.
    float edge = noise(dirp * 2.5 + vec2(rho * 0.35, seed));
    float radial = smoothstep(0.6, 0.85, rho) * smoothstep(11.0, 3.5, rho + (edge - 0.5) * 4.0);
    if (radial <= 0.0) {
        return vec4(0.0);
    }
    // Inner gas orbits faster. Two copies of the swirl are cross-faded, each restarting while it's
    // invisible, so the shear never winds the texture up into noise however long it runs.
    const float FLOW_PERIOD = 16.0;
    float phA = fract(t / FLOW_PERIOD);
    float phB = fract(phA + 0.5);
    float wA = 1.0 - abs(2.0 * phA - 1.0);
    float wB = 1.0 - wA;
    float omega = spinDir * 0.35 / pow(rho, 1.5);
    float shear = 1.5 * abs(omega) / rho * FLOW_PERIOD * fpRho;
    float nA = diskLayer(rho, dirp, omega * phA * FLOW_PERIOD, seed, fpRho, fpDir + shear * phA);
    float nB = diskLayer(rho, dirp, omega * phB * FLOW_PERIOD, seed + 19.0, fpRho, fpDir + shear * phB);
    // Renormalise so contrast stays constant through the cross-fade.
    const float mean = 0.55;
    float n = mean + ((nA - mean) * wA + (nB - mean) * wB) / sqrt(wA * wA + wB * wB);

    // The innermost gas is always dense and hot, giving an even bright rim around the hole.
    float dens = max(smoothstep(0.2, 0.85, n), smoothstep(1.4, 0.7, rho) * 0.75);
    float heat = clamp(2.4 / rho, 0.0, 1.0);
    float b = dens * (0.35 + 0.9 * heat);
    vec3 c = mix(DISK_DUST, DISK_AMBER, smoothstep(0.08, 0.45, b));
    c = mix(c, DISK_WHITE, smoothstep(0.45, 0.85, b));
    float a = radial * clamp(0.65 + dens * 0.5, 0.0, 1.0);
    return vec4(c * (0.2 + b * 1.5) * a, a);
}

// Ray-traced black hole geometry. Inside the trace, distances are in Schwarzschild radii; on
// screen the shadow has radius R.
const float B_CRIT = 2.598;       // shadow radius in Schwarzschild radii (3*sqrt(3)/2)
const float CAM_DIST = 60.0;
const float LENS_DIST = 12.0;     // where bent background light is projected; sets lensing strength
const float TRACE_RADIUS = 12.0;  // in shadow radii; further out, lensing is done analytically

// Gargantua-style black hole (Interstellar), ray traced: each pixel's light ray is bent around a
// Schwarzschild black hole and picks up the accretion disk wherever it crosses the disk plane.
// The arch over the top, the ring underneath and the thin inner rings are all the same disk seen
// through bent light, so they're symmetric and flow together with the disk.
// Must be called from uniform control flow (it uses screen-space derivatives).
void blackHole(vec2 uv, float seed, float slot, float lt, float t, float fade,
               out vec2 bgUv, out float shadow, out vec4 overlay) {
    vec2 rnd = hash22(vec2(slot * 2.3, seed + 41.0));
    // Mostly small-to-medium, occasionally huge.
    float R = mix(0.035, 0.12, pow(hash12(vec2(slot, seed + 43.0)), 1.6));
    vec2 center = (rnd - 0.5) * 2.0 * halfExtent() * vec2(0.6, 0.45);
    center += (hash22(vec2(slot, seed + 47.0)) - 0.5) * 0.0004 * lt;
    float tilt = (hash12(vec2(slot, seed + 53.0)) - 0.5) * 0.35;
    // Camera sits a few degrees above the disk plane, nearly edge-on like in the film.
    float incl = mix(0.035, 0.06, hash12(vec2(slot, seed + 59.0)));
    float spinDir = hash12(vec2(slot, seed + 61.0)) < 0.5 ? -1.0 : 1.0;

    vec2 d = uv - center;
    vec2 dt = rotate(tilt) * d / R; // screen offset in shadow radii, in the disk's frame
    float rr = length(dt);

    vec3 N = vec3(0.0, cos(incl), -sin(incl)); // disk normal, tipped toward the camera
    vec3 V = vec3(0.0, sin(incl), cos(incl));  // in-plane axis pointing away from the camera

    vec3 pos = vec3(dt * B_CRIT, -CAM_DIST);
    vec3 vel = vec3(0.0, 0.0, 1.0);
    int hits = 0;
    float hitRho[3] = float[3](0.0, 0.0, 0.0);
    vec2 hitDir[3] = vec2[3](vec2(0.0), vec2(0.0), vec2(0.0));
    float hitBeam[3] = float[3](1.0, 1.0, 1.0);
    float hitNear[3] = float[3](0.0, 0.0, 0.0);

    if (rr < TRACE_RADIUS) {
        vec3 L = cross(pos, vel);
        float h2 = dot(L, L);
        float f = dot(pos, N);
        for (int i = 0; i < 200; i++) {
            float r = length(pos);
            if (r < 1.0 || (r > CAM_DIST + 5.0 && dot(pos, vel) > 0.0)) {
                break;
            }
            // Photon path around a Schwarzschild mass: a = -1.5 h^2 x / r^5.
            float h = max(0.02, 0.07 * r);
            vel += -1.5 * h2 * pos / (r * r * r * r * r) * h;
            vec3 np = pos + vel * h;
            float nf = dot(np, N);
            if (f * nf < 0.0 && hits < 3) {
                vec3 hit = mix(pos, np, f / (f - nf));
                float rhoRs = length(hit);
                if (rhoRs > 1.0 && rhoRs < 32.0) {
                    hitRho[hits] = rhoRs / B_CRIT;
                    hitDir[hits] = vec2(hit.x, dot(hit, V)) / rhoRs;
                    // Gas orbiting toward us is brighter.
                    vec3 orbit = normalize(cross(N, hit)) * spinDir;
                    hitBeam[hits] = 1.0 + 0.3 * dot(orbit, -normalize(vel));
                    hitNear[hits] = dot(hit, V);
                    hits++;
                }
            }
            pos = np;
            f = nf;
        }
    }

    // Where the ray ends up on the sky behind the hole.
    vec2 offs;
    if (rr >= TRACE_RADIUS) {
        vec2 b = dt * B_CRIT;
        offs = b * (1.0 - 2.0 * LENS_DIST / dot(b, b)); // weak-field lensing, matches the trace
    } else if (vel.z > 0.05) {
        offs = pos.xy + vel.xy * ((LENS_DIST - pos.z) / vel.z);
    } else {
        offs = pos.xy + normalize(vel.xy + 1e-5) * 400.0; // bent sharply back
    }
    vec2 lensUv = center + rotate(-tilt) * (offs / B_CRIT) * R;
    bgUv = mix(uv, lensUv, fade);

    float r = length(d);
    float px = 1.5 / minDim();
    float outside = smoothstep(R - px, R + px, r);
    // Darken the sky around it, nearly black right at the edge where lensing squeezes stars to specks.
    float dim = mix(0.1, 1.0, smoothstep(1.1 * R, 6.0 * R, r));
    shadow = mix(1.0, outside * dim, fade);

    // Shade disk crossings front to back. Footprints are taken outside any divergent branch.
    overlay = vec4(0.0);
    for (int k = 0; k < 3; k++) {
        float fpRho = fwidth(hitRho[k]);
        float fpDir = length(fwidth(hitDir[k]));
        if (k < hits) {
            vec4 s = diskSample(hitRho[k], hitDir[k], t, spinDir, seed, fpRho, fpDir);
            s.rgb *= hitBeam[k];
            // The near side of the disk, crossing in front of the hole, shows its dustier face.
            float dusty = smoothstep(0.0, -3.0 * B_CRIT, hitNear[k]);
            s.rgb *= mix(1.0, 0.6, dusty);
            s.a = min(1.0, s.a * mix(1.0, 1.6, dusty));
            overlay += (1.0 - overlay.a) * s;
        }
    }
    overlay *= fade;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 screen = fragCoord / iResolution.xy;
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / minDim();
    vec2 seed = vec2(iResolution.x * 0.0013, iResolution.y * 0.0007);
    float t = iTime;

    float slot = floor(t / EVENT_PERIOD);
    float lt = t - slot * EVENT_PERIOD;
    float fade = smoothstep(0.0, EVENT_FADE, lt) * smoothstep(EVENT_PERIOD, EVENT_PERIOD - EVENT_FADE, lt);
    float eventSeed = seed.x + seed.y * 3.0;
    float roll = hash12(vec2(slot, eventSeed));
    bool hasHole = roll < BLACKHOLE_CHANCE; // same for every pixel, so derivatives inside stay valid
    bool hasStar = !hasHole && roll < BLACKHOLE_CHANCE + STAR_CHANCE;
    bool hasSystem = !hasHole && !hasStar && roll < BLACKHOLE_CHANCE + STAR_CHANCE + SYSTEM_CHANCE;
    float cut = BLACKHOLE_CHANCE + STAR_CHANCE + SYSTEM_CHANCE;
    bool hasComet = !hasHole && !hasStar && !hasSystem && roll < cut + COMET_CHANCE;
    bool hasField = !hasHole && !hasStar && !hasSystem && !hasComet && roll < cut + COMET_CHANCE + FIELD_CHANCE;
    bool hasPlanet = !hasHole && !hasStar && !hasSystem && !hasComet && !hasField
            && roll < cut + COMET_CHANCE + FIELD_CHANCE + PLANET_CHANCE;

    vec2 bgUv = uv;
    float shadow = 1.0;
    vec4 holeOverlay = vec4(0.0);
    if (hasHole) {
        blackHole(uv, eventSeed, slot, lt, t, fade, bgUv, shadow, holeOverlay);
    }
    // How much the lens squeezes the sky here (1 = not at all).
    float lens = clamp(length(fwidth(bgUv)) / length(fwidth(uv)), 1.0, 8.0);

    vec4 sun = vec4(0.0);
    vec3 sunGlow = vec3(0.0);
    float shimmer = 0.0;
    if (hasStar) {
        float kind = hash12(vec2(slot, eventSeed + 71.0));
        float sz = hash12(vec2(slot, eventSeed + 73.0));
        bool giant = kind >= STAR_GIANT && kind < STAR_BLUE;
        float radius = giant ? mix(0.25, 0.45, sz) : kind >= STAR_BLUE ? mix(0.07, 0.13, sz) : mix(0.12, 0.22, sz);
        vec2 center = (hash22(vec2(slot * 3.1, eventSeed + 75.0)) - 0.5) * 2.0 * halfExtent() * 0.8;
        center += (hash22(vec2(slot, eventSeed + 77.0)) - 0.5) * 0.0004 * lt;
        sun = star(uv, center, radius, kind, eventSeed, slot, t, fade, sunGlow, shimmer);
    }
    vec4 system = vec4(0.0);
    if (hasSystem) {
        system = solarSystem(uv, eventSeed, slot, t, fade, shimmer);
    }
    // Heat shimmer: the sky behind a star's corona ripples, with waves rising over time.
    vec2 wob = vec2(noise(uv * 40.0 + vec2(0.0, t * 1.2)), noise(uv * 40.0 + vec2(t * 1.2, 7.0))) - 0.5;
    bgUv += wob * shimmer * 0.004;

    vec3 col = mix(vec3(0.035, 0.015, 0.060), vec3(0.008, 0.010, 0.030), screen.y);

    float dens;
    // Asteroid fields get plain dark space behind them: the nebula fades out as the field fades in.
    float nebulaAmount = hasField ? 1.0 - fade : 1.0;
    col += nebula(bgUv, seed, t, dens) * nebulaAmount;
    dens *= nebulaAmount;

    vec3 stars = vec3(0.0);
    stars += starLayer(bgUv + vec2(t * 0.0030, t * 0.0010), 60.0, 0.14, 1.00, seed.x, t, lens);
    stars += starLayer(bgUv + vec2(t * 0.0018, t * 0.0006), 110.0, 0.08, 0.70, seed.x + 41.0, t, lens);
    stars += starLayer(bgUv + vec2(t * 0.0009, t * 0.0003), 200.0, 0.05, 0.45, seed.x + 97.0, t, lens);
    col += stars * (1.0 - dens * 0.4);
    col += heatStars(bgUv + vec2(t * 0.0012, t * 0.0004), seed.x + 300.0, t, lens);

    if (hasPlanet) {
        vec3 glow;
        vec4 p = planet(uv, eventSeed, slot, lt, t, fade, glow);
        col = col * (1.0 - p.a) + p.rgb + glow;
    }
    col = col * (1.0 - sun.a) + sun.rgb + sunGlow;
    col = col * (1.0 - system.a) + system.rgb;
    if (hasField) {
        vec4 field = asteroidField(uv, eventSeed, slot, t, fade);
        col = col * (1.0 - field.a) + field.rgb;
    }
    if (hasComet) {
        col += comet(uv, eventSeed, slot, lt, t, fade);
    }

    col = col * shadow;
    col = col * (1.0 - holeOverlay.a) + holeOverlay.rgb;

    vec2 c = screen - 0.5;
    col *= 1.0 - 0.35 * dot(c, c);

    // Soft tonemap so hot stars and bright cores don't clip harshly, plus a static dither.
    col = col / (1.0 + col * 0.25);
    col += (hash12(fragCoord) - 0.5) / 255.0;

    fragColor = vec4(col, 1.0);
}
