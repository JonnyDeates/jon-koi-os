// Standing on the surface of a moon of a gas giant, at eye level. The airless ground is
// ray-marched as real terrain: rolling regolith pocked with craters of every size, raised rims
// that hide what lies beyond them, boulders at our feet, and a lumpy skyline of hills with
// mountains further off. With no air there's no haze, so the far ground is as crisp as the near
// and shadows are pitch black. A low sun rakes across it and throws long shadows. Above hangs
// the huge giant (rings, storms and all), lit from the same sun, so its phase matches the light
// on the ground; its day side throws a faint coloured light of its own. Sometimes the sun has
// set, and the giant alone lights the ground. Worlds vary: grey and cratered, cracked water ice,
// sulphur-yellow volcanic, or dark and battered. We slowly turn our head.
// Sometimes the sun slides behind the giant over the event: the land goes dark under a ring of
// sunlight glowing through the giant's air, then the sun re-emerges. And sometimes a small inner
// moon races across the sky every few minutes, its phase lit by the same sun.
// Units are metres. Premultiplied colour/coverage.

const float MOON_R = 60000.0;  // moon radius: the ground curves away beyond a few hundred metres

// Value noise with its gradient: (value, d/dx, d/dy).
vec3 moonNoiseD(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    vec2 du = 6.0 * f * (1.0 - f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    float k = a - b - c + d;
    return vec3(a + (b - a) * u.x + (c - a) * u.y + k * u.x * u.y,
                du * vec2(b - a + k * u.y, c - a + k * u.x));
}

// One layer of craters on a grid of cells of size s, at most one per cell and sitting inside it.
// Returns (height, gradient). fresh gets how young the crater here is (bright, sharp ejecta).
vec3 moonCraters(vec2 p, float s, float ang, float dens, float seed, inout float fresh) {
    vec2 g = rotate(ang) * p / s;
    vec2 id = floor(g);
    if (hash12(id + seed) > dens) {
        return vec3(0.0);
    }
    float r = mix(0.1, 0.33, pow(hash12(id + seed + 1.3), 1.5));
    vec2 c = 0.5 + (hash22(id + seed + 2.7) - 0.5) * 2.0 * max(0.5 - 1.45 * r, 0.0);
    vec2 o = fract(g) - c;
    float q = length(o) / r;
    if (q > 1.45) {
        return vec3(0.0);
    }
    // Older craters have been worn down by later impacts: shallower, softer rims.
    float age = hash12(id + seed + 4.1);
    float depth = 0.36 * r * mix(0.35, 1.0, age);
    float rimH = 0.08 * r * mix(0.3, 1.0, age);
    float e = q - 1.0;
    float rimW = e < 0.0 ? mix(0.25, 0.1, age) : 0.35;
    float rg = exp(-e * e / (rimW * rimW)) * smoothstep(1.45, 1.2, q);
    float h = rimH * rg;
    float dh = rimH * rg * (-2.0 * e / (rimW * rimW));
    if (q < 1.0) {
        // Bowl that eases into the rim instead of meeting it at a crease.
        float k = 1.0 - q * q;
        h -= depth * k * sqrt(k) * 1.3;
        dh += depth * 3.0 * q * sqrt(k) * 1.3;
    }
    if (age > 0.88) {
        // A bright halo of ejecta around the rim, fading outward.
        fresh = max(fresh, smoothstep(0.7, 1.0, q) * smoothstep(1.45, 1.0, q) * (age - 0.88) / 0.12);
    }
    vec2 dir = o / max(length(o), 1e-5);
    // Height in cell units -> ground units, gradient back into the unrotated frame.
    return vec3(h * s, (dh / r * dir) * rotate(ang));
}

// Scattered boulders: low rounded humps on a grid of cells of size s.
vec3 moonBoulders(vec2 p, float s, float dens, float seed, inout float boulder) {
    vec2 g = p / s;
    vec2 id = floor(g);
    if (hash12(id + seed) > dens) {
        return vec3(0.0);
    }
    float r = mix(0.06, 0.2, pow(hash12(id + seed + 1.1), 2.5));
    vec2 o = fract(g) - (0.5 + (hash22(id + seed + 2.2) - 0.5) * (1.0 - 2.8 * r));
    // Irregular outline, so they read as rocks rather than domes.
    float ang = atan(o.y, o.x);
    float ph = hash12(id + seed + 3.3) * 6.2831;
    r *= 1.0 + 0.12 * sin(2.0 * ang + ph) + 0.05 * sin(3.0 * ang - ph * 2.0);
    float q = length(o) / r;
    if (q >= 0.96) {
        return vec3(0.0);
    }
    // A partly buried rock: a rounded lump cut by a few tilted faces, so it's angular.
    float sk = sqrt(1.0 - q * q);
    boulder = max(boulder, smoothstep(0.96, 0.8, q));
    vec2 dir = o / max(length(o), 1e-5);
    float hh = sk - 0.28;
    vec2 gg = -q / sk * dir;
    for (int j = 0; j < 3; j++) {
        float a = ph + float(j) * 2.1 + hash12(id + seed + float(j) * 5.1) * 1.2;
        vec2 nd = vec2(cos(a), sin(a));
        float tiltK = mix(0.5, 1.1, hash12(id + seed + float(j) * 7.3));
        float hp = mix(0.4, 0.62, hash12(id + seed + float(j) * 9.7)) - tiltK * dot(o / r, nd);
        if (hp < hh) {
            hh = hp;
            gg = -tiltK * nd;
        }
    }
    float hs = mix(0.6, 1.0, hash12(id + seed + 4.4));
    return vec3(r * hh * s * hs, gg * hs);
}

// Height of the ground at p with its gradient. Detail finer than the footprint fp is left out,
// so the far ground doesn't shimmer and the marching and shadow tests stay cheap. mtn is
// (distance where the mountains start, their height). Craters and rocks on cells smaller than
// minS are skipped: marching only needs shapes big enough to change the outline.
vec3 moonGround(vec2 p, float fp, float seed, float cdens, vec2 mtn, float minS, out float fresh, out float boulder) {
    fresh = 0.0;
    boulder = 0.0;
    vec3 n0 = moonNoiseD(p / 600.0 + seed * 0.7);
    vec3 n1 = moonNoiseD(p / 160.0 + seed);
    vec3 n2 = moonNoiseD(p / 37.0 - seed);
    vec3 h = vec3(n0.x * 10.0, n0.yz * 10.0 / 600.0) + vec3(n1.x * 6.0, n1.yz * 6.0 / 160.0)
           + vec3(n2.x * 1.3, n2.yz * 1.3 / 37.0);
    float s = 260.0;
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float keep = smoothstep(2.0, 6.0, s * 0.18 / fp);
        if (keep > 0.0 && s >= minS) {
            // Small craters are more common than big ones.
            h += moonCraters(p, s, fi * 1.7 + 0.4, min(cdens * (0.6 + 0.1 * fi), 0.95), seed + fi * 13.0, fresh) * keep;
        }
        s *= 0.42;
    }
    // Boulders at two sizes: big rocks scattered sparsely, small stones everywhere.
    float keepB = smoothstep(2.0, 6.0, 1.2 / fp) * step(minS, 9.0);
    if (keepB > 0.0) {
        h += moonBoulders(p, 9.0, 0.1, seed + 83.0, boulder) * keepB;
    }
    float keep = smoothstep(2.0, 6.0, 0.4 / fp) * step(minS, 2.6);
    if (keep > 0.0) {
        h += moonBoulders(p, 2.6, 0.22, seed + 71.0, boulder) * keep;
    }
    boulder *= keepB;
    // Mountains: ridged ranges rising from mtn.x outward.
    float r = length(p);
    if (r > mtn.x) {
        float x = min((r - mtn.x) / (mtn.x * 0.6), 1.0);
        float mm = x * x * (3.0 - 2.0 * x);
        float dmm = 6.0 * x * (1.0 - x) / (mtn.x * 0.6);
        vec3 a = moonNoiseD(p / 450.0 + seed * 1.7);
        vec3 b = moonNoiseD(rotate(0.8) * p / 160.0 - seed * 1.3);
        float ra = 1.0 - abs(2.0 * a.x - 1.0);
        vec2 ga = -2.0 * sign(2.0 * a.x - 1.0) * a.yz / 450.0;
        float rb = 1.0 - abs(2.0 * b.x - 1.0);
        vec2 gb = -2.0 * sign(2.0 * b.x - 1.0) * (b.yz * rotate(0.8)) / 160.0;
        // Sharp ridges with craggy detail along their tops.
        float m = ra * ra * 0.75 + rb * ra * 0.25;
        vec2 gm = ra * ga * 1.5 + (gb * ra + rb * ga) * 0.25;
        h += mtn.y * vec3(mm * m, mm * gm + m * dmm * p / r);
    }
    // The moon curving away.
    h -= vec3(dot(p, p), 2.0 * p) / (2.0 * MOON_R);
    return h;
}

// Just the big shapes of the ground, height only: the hills, the two largest crater sizes,
// the mountains, and (when rocks) the big boulders. Used for marching and shadows; matches
// moonGround apart from the small detail, which only shades the surface.
float moonCraterH(vec2 p, float s, float ang, float dens, float seed) {
    vec2 g = rotate(ang) * p / s;
    vec2 id = floor(g);
    if (hash12(id + seed) > dens) {
        return 0.0;
    }
    float r = mix(0.1, 0.33, pow(hash12(id + seed + 1.3), 1.5));
    vec2 c = 0.5 + (hash22(id + seed + 2.7) - 0.5) * 2.0 * max(0.5 - 1.45 * r, 0.0);
    float q = length(fract(g) - c) / r;
    if (q > 1.45) {
        return 0.0;
    }
    float age = hash12(id + seed + 4.1);
    float e = q - 1.0;
    float rimW = e < 0.0 ? mix(0.25, 0.1, age) : 0.35;
    float h = 0.08 * r * mix(0.3, 1.0, age) * exp(-e * e / (rimW * rimW)) * smoothstep(1.45, 1.2, q);
    if (q < 1.0) {
        float k = 1.0 - q * q;
        h -= 0.36 * r * mix(0.35, 1.0, age) * k * sqrt(k) * 1.3;
    }
    return h * s;
}

float moonHeight(vec2 p, float seed, float cdens, vec2 mtn, bool rocks, bool fine) {
    float h = noise(p / 600.0 + seed * 0.7) * 10.0 + noise(p / 160.0 + seed) * 6.0;
    if (fine) {
        h += noise(p / 37.0 - seed) * 1.3;
    } else {
        h += 0.65;
    }
    h += moonCraterH(p, 260.0, 0.4, min(cdens * 0.6, 0.95), seed);
    h += moonCraterH(p, 109.2, 2.1, min(cdens * 0.7, 0.95), seed + 13.0);
    if (rocks) {
        float bo = 0.0;
        h += moonBoulders(p, 9.0, 0.1, seed + 83.0, bo).x;
    }
    float r = length(p);
    if (r > mtn.x) {
        float x = min((r - mtn.x) / (mtn.x * 0.6), 1.0);
        float ra = 1.0 - abs(2.0 * noise(p / 450.0 + seed * 1.7) - 1.0);
        float rb = 1.0 - abs(2.0 * noise(rotate(0.8) * p / 160.0 - seed * 1.3) - 1.0);
        h += mtn.y * x * x * (3.0 - 2.0 * x) * (ra * ra * 0.75 + rb * ra * 0.25);
    }
    return h - dot(p, p) / (2.0 * MOON_R);
}

vec3 moonRx(vec3 v, float a) {
    float c = cos(a), s = sin(a);
    return vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
}

vec3 moonRy(vec3 v, float a) {
    float c = cos(a), s = sin(a);
    return vec3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c);
}

// Lunar-style reflectance (Lommel-Seeliger): dusty ground looks about as bright seen edge-on
// as face-on, with no dark limb.
float moonLS(vec3 n, vec3 l, float mu) {
    float mu0 = max(dot(n, l), 0.0);
    return 2.0 * mu0 / (mu0 + mu);
}

// Everything about the moon's sky that doesn't depend on the ground: camera, sun, giant, eclipse.
struct MoonSky {
    float hy, pitch, yaw;
    bool night, eclipse;
    vec3 L, G, Gc, Lc;
    float gR, sunVis, sunNear;
    vec2 gCenter;
    GiantView gv;
};

const float MOON_F = 1.2;    // focal length (screen short side = 1)
const float SUN_R = 0.011;   // the sun's screen radius during an eclipse

MoonSky moonSky(float seed, float slot, float t) {
    float lt = eventTime(t);
    vec2 ext = halfExtent();
    const float f = MOON_F;
    // Camera: horizon low on screen, slowly turning.
    float hy = mix(-0.3, -0.14, hash12(vec2(slot, seed + 603.0)));
    float pitch = atan(hy / f);
    float yaw = (hash12(vec2(slot, seed + 605.0)) - 0.5) * 0.0012 * eventDrift(lt);

    // Sun: low, off to one side (out of frame). Now and then it has set.
    bool night = hash12(vec2(slot, seed + 607.0)) < 0.2;
    float el = night ? -mix(0.08, 0.4, hash12(vec2(slot, seed + 609.0))) : mix(0.08, 0.35, hash12(vec2(slot, seed + 609.0)));
    float az = (night ? mix(0.2, 1.2, hash12(vec2(slot, seed + 611.0))) : mix(0.5, 2.3, hash12(vec2(slot, seed + 611.0))))
             * (hash12(vec2(slot, seed + 613.0)) < 0.5 ? -1.0 : 1.0);
    vec3 L = vec3(sin(az) * cos(el), sin(el), cos(az) * cos(el));

    // The giant: fixed in this moon's sky (it's tidally locked), placed relative to the start view.
    float gR = mix(0.16, 0.4, hash12(vec2(slot, seed + 615.0)));
    vec2 gs0 = vec2((hash12(vec2(slot, seed + 617.0)) - 0.5) * 1.2 * ext.x,
                    mix(hy + gR * 0.5, ext.y * 0.55, hash12(vec2(slot, seed + 619.0))));
    bool eclipse = !night && hash12(vec2(slot, seed + 627.0)) < 0.25;
    if (eclipse) {
        // Keep the giant well clear of the horizon, so the sun's path beside it stays in the sky.
        gs0.y = max(gs0.y, hy + gR * 1.3 + 0.06);
    }
    vec3 G = moonRx(normalize(vec3(gs0, -f)), -pitch);
    float gA = gR / f;          // the giant's angular radius
    float sunA = SUN_R / f;

    // Eclipse, sometimes: the sun is up beside the giant and creeps behind it over the event, then
    // out the other side. Its path passes a little off centre.
    float sunVis = 1.0;
    float sunNear = 0.0;
    if (eclipse) {
        vec3 tx = normalize(cross(G, vec3(0.0, 1.0, 0.0)));
        vec3 ty = cross(tx, G);
        // Mostly sideways, so it neither rises from nor sets into the ground on the way.
        float tAng = (hash12(vec2(slot, seed + 629.0)) - 0.5) * 0.9 + (hash12(vec2(slot, seed + 630.0)) < 0.5 ? 0.0 : 3.1416);
        vec2 tdir = vec2(cos(tAng), sin(tAng));
        float miss = (hash12(vec2(slot, seed + 631.0)) - 0.5) * gA * 0.9;
        float along = mix(-2.6, 2.6, lt / EVENT_PERIOD) * gA;
        vec2 o = tdir * along + vec2(-tdir.y, tdir.x) * miss;
        L = normalize(G + tx * o.x + ty * o.y);
        float dAng = acos(clamp(dot(L, G), -1.0, 1.0));
        sunVis = smoothstep(gA - sunA, gA + sunA, dAng);
        sunNear = smoothstep(gA * 1.7, gA * 0.95, dAng);
    }
    vec3 Gc = moonRx(moonRy(G, -yaw), pitch);
    vec2 gCenter = f * Gc.xy / -Gc.z;
    vec3 Lc = moonRx(moonRy(L, -yaw), pitch);
    // Sun direction in the giant's own view frame (z pointing from it toward us).
    vec3 zg = -Gc;
    vec3 xg = normalize(cross(vec3(0.0, 1.0, 0.0), zg));
    vec3 yg = cross(zg, xg);
    MoonSky ms;
    ms.hy = hy; ms.pitch = pitch; ms.yaw = yaw;
    ms.night = night; ms.eclipse = eclipse;
    ms.L = L; ms.G = G; ms.Gc = Gc; ms.Lc = Lc;
    ms.gR = gR; ms.sunVis = sunVis; ms.sunNear = sunNear;
    ms.gCenter = gCenter;
    ms.gv = GiantView(gCenter, gR, vec3(dot(Lc, xg), dot(Lc, yg), dot(Lc, zg)), vec4(0.0), 1.0);
    return ms;
}

// ms: the sky set-up; giantIn/gTintIn: the giant, already drawn by the shared renderer.
vec4 moonSurface(vec2 uv, float seed, float slot, float t, float fade, MoonSky ms, vec4 giantIn, vec3 gTintIn) {
    float lt = eventTime(t);
    vec2 ext = halfExtent();
    const float f = MOON_F;
    float pxA = 1.0 / (f * minDim());

    // World kind: albA is the main ground, albB the darker patches or crack colour.
    float pick = hash12(vec2(slot, seed + 601.0));
    vec3 albA, albB;
    float cdens;
    int kind;
    if (pick < 0.4) {           // grey, like our Moon: bright highlands, dark maria
        albA = vec3(0.3, 0.29, 0.28); albB = vec3(0.16, 0.155, 0.15); cdens = 0.85; kind = 0;
    } else if (pick < 0.62) {   // icy, like Europa: white ice crossed by rusty cracks
        albA = vec3(0.5, 0.55, 0.6); albB = vec3(0.36, 0.22, 0.15); cdens = 0.3; kind = 1;
    } else if (pick < 0.77) {   // volcanic sulphur, like Io: hardly any craters
        albA = vec3(0.52, 0.44, 0.2); albB = vec3(0.42, 0.18, 0.08); cdens = 0.03; kind = 2;
    } else {                    // dark and old, like Callisto: crater on crater
        albA = vec3(0.19, 0.165, 0.14); albB = vec3(0.11, 0.095, 0.08); cdens = 0.95; kind = 3;
    }
    vec2 mtn = vec2(mix(600.0, 1200.0, hash12(vec2(slot, seed + 625.0))), mix(25.0, 120.0, hash12(vec2(slot, seed + 621.0))));

    // Camera: at eye height above the ground where we stand.
    float fr0, bo0;
    float H0 = moonGround(vec2(0.0), 0.05, seed, cdens, mtn, 0.0, fr0, bo0).x;
    vec3 ro = vec3(0.0, H0 + 1.7, 0.0);
    float hy = ms.hy, pitch = ms.pitch, yaw = ms.yaw;
    bool night = ms.night, eclipse = ms.eclipse;
    vec3 L = ms.L, G = ms.G, Gc = ms.Gc, Lc = ms.Lc;
    float gR = ms.gR, sunVis = ms.sunVis, sunNear = ms.sunNear;
    vec2 gCenter = ms.gCenter;
    vec4 giant = giantIn;
    vec3 gTint = gTintIn;
    // Light from the giant's day side: brighter the fuller it is and the more sky it fills.
    float gPhase = 0.5 + 0.5 * dot(L, -G);
    vec3 gShine = gTint * gPhase * min(gR * gR / (f * f) * 16.0, 1.2);
    // During the eclipse the ring of light around the giant still casts a faint coppery glow.
    gShine += vec3(1.0, 0.55, 0.3) * sunNear * (1.0 - sunVis) * 0.05;
    vec3 sunC = vec3(1.0, 0.97, 0.92) * 0.45 * smoothstep(-0.01, 0.03, L.y) * sunVis;
    float pxU = 1.0 / minDim();

    // The sky behind the ground: the sun (only ever in view during an eclipse), the giant, and
    // sometimes a small inner moon racing across.
    vec4 sunDisc = vec4(0.0);
    vec2 sunSp = vec2(1e3);
    if (eclipse && Lc.z < 0.0) {
        sunSp = f * Lc.xy / -Lc.z;
        float dsn = length(uv - sunSp);
        float disc = smoothstep(SUN_R + pxU, SUN_R - pxU, dsn);
        sunDisc = vec4(vec3(1.0, 0.97, 0.9) * 6.0 * disc, 0.0);
    }
    vec4 skyL = over(giant, sunDisc);
    if (hash12(vec2(slot, seed + 633.0)) < 0.5) {
        // Inner moon: a pass every few minutes, crossing the sky in a couple of minutes.
        const float PASS = 330.0;
        float pi = floor(lt / PASS);
        float pt = (lt - pi * PASS) / 140.0;
        if (pt < 1.0) {
            float hp = hash12(vec2(pi + slot * 7.0, seed + 635.0));
            vec2 a0 = vec2(-ext.x - 0.08, mix(hy + 0.12, ext.y * 0.75, hp));
            vec2 a1 = vec2(ext.x + 0.08, mix(hy + 0.12, ext.y * 0.75, hash12(vec2(pi, seed + 637.0))));
            if (hash12(vec2(pi, seed + 639.0)) < 0.5) {
                vec2 tmp = a0; a0 = a1; a1 = tmp;
            }
            vec2 mc = mix(a0, a1, pt) + vec2(0.0, sin(pt * 3.1416) * 0.06);
            float mr = mix(0.022, 0.045, hash12(vec2(pi, seed + 641.0)));
            vec2 md = (uv - mc) / mr;
            float rr = length(md);
            if (rr < 1.0 + pxU / mr) {
                vec3 n = vec3(md, sqrt(max(1.0 - rr * rr, 0.0)));
                float mu = max(n.z, 0.05);
                // Cratered grey rock, lit by the same sun (so its phase matches) and by the giant.
                float tex = fbm(md * 2.5 + hp * 40.0) * 0.6 + fbm(md * 7.0 - hp * 20.0) * 0.4;
                vec3 malb = vec3(0.34, 0.32, 0.3) * (0.6 + 0.8 * tex);
                vec3 mcol = malb * (sunC * 2.2 * moonLS(n, Lc, mu) + gShine * moonLS(n, Gc, mu) + 0.004);
                float mcov = smoothstep(1.0 + pxU / mr, 1.0 - pxU / mr, rr);
                vec4 inner = vec4(mcol * mcov, mcov);
                // Some passes go in front of the giant, some behind it.
                skyL = hash12(vec2(pi, seed + 643.0)) < 0.6 ? over(inner, skyL) : over(giant, over(inner, sunDisc));
            }
        }
    }
    if (eclipse) {
        // Sunlight glowing through the giant's atmosphere as a thin ring around its dark disc,
        // brightest on the side nearest the sun, reddened low in the air.
        vec2 gv = uv - gCenter;
        float rg = length(gv) / gR;
        vec2 toSun = normalize(sunSp - gCenter + 1e-5);
        float side = mix(0.25, 1.0, pow(0.5 + 0.5 * dot(gv / max(length(gv), 1e-5), toSun), 2.0));
        float ringW = 0.012 + 0.02 * sunNear;
        float ring = exp(-pow((rg - 1.0) / ringW, 2.0)) + exp(-max(rg - 1.0, 0.0) / 0.06) * step(1.0, rg) * 0.25;
        skyL.rgb += mix(vec3(1.0, 0.45, 0.2), vec3(1.0, 0.9, 0.75), side) * ring * side * sunNear * (1.0 - sunVis * 0.6) * 1.2;
        // Glare from whatever part of the sun still shows.
        float dsn = length(uv - sunSp);
        skyL.rgb += vec3(1.0, 0.95, 0.85) * (exp(-dsn / 0.025) * 0.8 + exp(-dsn / 0.12) * 0.2) * sunVis * smoothstep(-0.01, 0.02, L.y);
    }

    vec3 rd = moonRy(moonRx(normalize(vec3(uv, -f)), -pitch), yaw);

    // March the ray over the terrain. Above the tallest hills nothing nearer than the mountains
    // can be hit, so the march skips ahead to them; above the mountains it stops.
    const float HILLS = 27.0;
    float hiAll = HILLS + mtn.y;
    float tt = 0.2;
    bool hit = false;
    bool escaped = false;
    float kmin = 1e9; // closest approach, in pixels, for a soft edge on the skyline
    float tk = 0.0;
    float tPrev = 0.0;
    // Nothing on the ground rises more than about 0.12 rad above eye level.
    if (rd.y < 0.13) {
        for (int i = 0; i < 200; i++) {
            vec3 pos = ro + rd * tt;
            if (rd.y > 0.0 && pos.y > hiAll) {
                escaped = true;
                break;
            }
            if (rd.y > 0.0 && pos.y > HILLS && tt < mtn.x) {
                tt = mtn.x;
                continue;
            }
            // Only shapes big enough to show in the outline are needed while marching.
            float hgt = pos.y - moonHeight(pos.xz, seed, cdens, mtn, tt < 12.0, tt < 150.0);
            float k = hgt / (tt * pxA);
            if (k < kmin) {
                kmin = k;
                tk = tt;
            }
            if (k < 0.5) {
                hit = true;
                break;
            }
            tPrev = tt;
            // The gap to the ground closes at most at the ray's own descent plus the steepest
            // slope of the coarse terrain (gentler past the rocks at our feet); overshoots are
            // caught by the refinement.
            float tr = tt * length(rd.xz);
            if (tr > mtn.x * 0.98) {
                // Among the mountains: steep ridges, so smaller steps or rays slip through them.
                tt += max(hgt / max(1.9 - rd.y, 1.0), 0.003 * tt);
            } else {
                tt += max(hgt / max((tt < 12.0 ? 0.8 : 0.45) - rd.y, 0.3), (tt < 12.0 ? 0.03 : 0.05) * tt + 0.01);
            }
            if (tt > 2500.0) {
                escaped = true;
                break;
            }
        }
        // A ray aimed clearly below eye level has to meet the ground; if it slipped between far
        // ridges or ran out of steps, put it where it came closest.
        // Likewise a ray that ran out of steps skimming along a ridge, within a few pixels of it.
        if (!hit && (rd.y < -0.01 || (!escaped && kmin < 4.0))) {
            hit = true;
            tt = tk;
        } else if (hit) {
            // The big steps can land well inside the ground: home in on the surface, then
            // interpolate between the last two heights so the hit point doesn't come out in steps.
            float a = tPrev, b = tt;
            vec3 pa = ro + rd * a;
            float ha = pa.y - moonHeight(pa.xz, seed, cdens, mtn, a < 12.0, true);
            float hb = -0.01;
            for (int j = 0; j < 6; j++) {
                float mid = 0.5 * (a + b);
                vec3 pos = ro + rd * mid;
                float hm = pos.y - moonHeight(pos.xz, seed, cdens, mtn, mid < 12.0, true);
                if (hm < 0.0) {
                    b = mid;
                    hb = hm;
                } else {
                    a = mid;
                    ha = hm;
                }
            }
            tt = mix(a, b, clamp(ha / max(ha - hb, 1e-5), 0.0, 1.0));
        }
    } else {
        escaped = true;
    }
    float cov = hit ? 1.0 : 1.0 - smoothstep(0.5, 1.5, kmin);
    vec3 col = vec3(0.0);
    if (cov > 0.0) {
        float tS = hit ? tt : tk;
        vec3 P = ro + rd * tS;
        float fp0 = tS * pxA;
        float fresh, boulder;
        vec3 hg = moonGround(P.xz, fp0, seed, cdens, mtn, 0.0, fresh, boulder);
        vec3 V = -rd;
        // Seen at a glancing angle a pixel covers a long strip of ground: textures fade sooner.
        vec3 n0 = normalize(vec3(-hg.y, 1.0, -hg.z));
        float fp = fp0 / max(abs(dot(n0, V)), 0.15);
        vec2 p = P.xz;
        // Rough regolith: bumps at a few scales, each fading out once smaller than a pixel;
        // rocks get a craggier surface.
        vec2 rough = vec2(0.0);
        float fr = 0.25;
        for (int i = 0; i < 4; i++) {
            float keepR = smoothstep(0.5, 0.15, fp * fr);
            if (keepR > 0.0) {
                rough += moonNoiseD(rotate(float(i) * 1.1) * p * fr + seed + float(i) * 3.7).yz * keepR
                       * (0.06 + 0.25 * boulder);
            }
            fr *= 2.9;
        }
        vec3 n = normalize(vec3(-hg.y - rough.x, 1.0, -hg.z - rough.y));
        float mu = max(dot(n, V), 0.05);

        // Shadows: march toward the sun over the terrain.
        float sh = 1.0;
        if (L.y > 0.0 && dot(n, L) > 0.0) {
            float st = 0.05 + fp0 * 2.0;
            vec3 Pb = vec3(P.x, max(P.y, hg.x + 0.01), P.z);
            for (int k = 0; k < 8; k++) {
                vec3 q = Pb + L * st;
                if (q.y > hiAll) {
                    break;
                }
                float hh = q.y - moonHeight(q.xz, seed, cdens, mtn, st < 5.0, st < 40.0);
                sh = min(sh, clamp(hh / (st * 0.012), 0.0, 1.0));
                if (sh <= 0.0) {
                    break;
                }
                st += max(hh * 0.8, st * 0.5 + 0.08);
            }
        }

        float m = fbmAA(p / 150.0 + seed, fp / 150.0);
        vec3 alb;
        if (kind == 1) {
            // Crack ridges at three scales, each faded out once too thin to draw.
            float crack = 0.0;
            float cs = 18.0;
            for (int i = 0; i < 3; i++) {
                float fi = float(i);
                float w = 0.035 + 0.6 * fp / cs;
                float l = 1.0 - smoothstep(0.0, w, abs(noise(rotate(fi * 1.3) * p / cs + seed + fi * 7.0) - 0.5));
                crack = max(crack, l * (0.45 + 0.2 * fi) * smoothstep(0.25, 0.08, w));
                cs *= 2.7;
            }
            alb = mix(albA, albB, crack);
            alb = mix(alb, albA * vec3(0.9, 0.85, 0.8), smoothstep(0.45, 0.7, m) * 0.5);
        } else if (kind == 2) {
            // Sulphur plains, red-brown lava patches and dark vents.
            alb = mix(albA, albB, smoothstep(0.45, 0.65, m));
            float vent = smoothstep(0.72, 0.8, fbmAA(p / 60.0 - seed, fp / 60.0));
            alb = mix(alb, vec3(0.06, 0.05, 0.04), vent);
            alb = mix(alb, vec3(0.75, 0.72, 0.6), smoothstep(0.3, 0.2, m) * 0.6);
        } else {
            alb = mix(albB, albA, smoothstep(0.38, 0.6, m));
        }
        alb *= 0.85 + 0.3 * mix(0.5, noise(p * 0.6 + seed), smoothstep(3.0, 1.0, fp * 0.6));
        // Fresh craters splash out bright ejecta; boulders are freshly exposed rock.
        alb = mix(alb, albA * 1.5 + 0.03, fresh * 0.45);
        alb = mix(alb, alb * vec3(1.15, 1.12, 1.1), boulder);

        // Brighter looking straight down-sun (shadows hidden behind what casts them).
        float g = acos(clamp(dot(L, V), -1.0, 1.0));
        float surge = 1.0 + 0.5 * exp(-g / 0.1);
        col = alb * sunC * (0.5 * moonLS(n, L, mu) + 2.0 * max(dot(n, L), 0.0)) * surge * sh;
        col += alb * gShine * moonLS(n, G, mu) + alb * 0.01;
    }

    return over(vec4(col * cov, cov), skyL) * fade;
}
