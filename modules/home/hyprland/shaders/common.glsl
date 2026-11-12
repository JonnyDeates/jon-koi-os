// Animated space wallpaper for shaderbg (Shadertoy-style mainImage; iTime/iResolution come from shaderbg).
// iResolution is in physical pixels (shaderbg is patched to render at the output's scale).

const vec3 KOI_BLUE = vec3(0.482, 0.788, 1.000);
const vec3 ROSE = vec3(0.922, 0.435, 0.573);
const vec3 TEAL = vec3(0.612, 0.812, 0.847);
const vec3 VIOLET = vec3(0.55, 0.28, 0.85);

// Events: each monitor rolls once per period for one event (or nothing). The event fades in,
// drifts, then fades out before the next roll.
const float EVENT_PERIOD = 150.0;
const float EVENT_FADE = 20.0;

const int EV_NONE = 0;
const int EV_HOLE = 1;
const int EV_STAR = 2;
const int EV_SYSTEM = 3;
const int EV_COMET = 4;
const int EV_FIELD = 5;
const int EV_PLANET = 6;
const int EV_SPIRAL = 7;
const int EV_PILLARS = 8;
const int EV_CRAB = 9;
const int EV_RING = 10;
const int EV_BIPOLAR = 11;
const int EV_ELLIPTICAL = 12;
const int EV_COMETCLOSE = 13;
const int EV_BINARY = 14;
const int EV_EATEN = 15;
const int EV_PULSAR = 16;
const int EV_PULSARCLOSE = 17;
const int EV_SUPERNOVA = 18;
const int EV_SURFACE = 19;
const int EV_COLLISION = 20;
const int EV_QUASAR = 21;
const int EV_ROGUE = 22;
const int EV_HORIZON = 23;
const int EV_CLUSTER = 24;
const int EV_GIANT = 25;
const int EV_MOON = 26;

// Set to an EV_* id to always show that event (space-wallpaper-preview does this).
const int FORCE_EVENT = -1;

// Replaced at launch with the run's seed (0-999.99), so every launch has its own sky and events.
const float RANDOM_SEED = 0.0;

// The background sky gets a new random layout and nebula palette every hour, cross-faded.
const float SKY_PERIOD = 3600.0;
const float SKY_FADE = 60.0;

// Share of event slots that show just the plain sky, so there are quiet stretches between events.
const float PLAIN_SKY_SHARE = 0.12;

// Relative weights of the events (they share the rest). The more GPU an event costs, the rarer it
// is (extra cost over plain sky at 4K in comments, measured from /proc/<pid>/fdinfo).
// Full-screen nebula events also skip the background nebula, so they can cost less than plain sky.
const float FIELD_CHANCE = 0.05;      // -3.3%
const float COMETCLOSE_CHANCE = 0.06; // -2.9%
const float CRAB_CHANCE = 0.05;       // -1.1%
const float RING_CHANCE = 0.04;       //  0.0%
const float PLANET_CHANCE = 0.04;     // +0.2%
const float COMET_CHANCE = 0.04;      // +0.7%
const float ELLIPTICAL_CHANCE = 0.04; // +2.0%
const float BIPOLAR_CHANCE = 0.04;    // +2.2%
const float PULSAR_CHANCE = 0.04;     // +2.2%
const float SPIRAL_CHANCE = 0.04;     // +3.0%
const float SYSTEM_CHANCE = 0.04;     // +3.1%
const float STAR_CHANCE = 0.04;       // +3.0%
const float PILLARS_CHANCE = 0.04;    // +3.9%
const float BLACKHOLE_CHANCE = 0.04;  // +4.1%
const float BINARY_CHANCE = 0.03;     // +4.0%
const float EATEN_CHANCE = 0.02;      // +5.4%
const float PULSARCLOSE_CHANCE = 0.02; // +7.3%
const float SUPERNOVA_CHANCE = 0.02;   // +5.0% (peak, during the shell)
const float SURFACE_CHANCE = 0.04;     // +2.1%
const float COLLISION_CHANCE = 0.04;   // +0.2%
const float QUASAR_CHANCE = 0.05;      // -3.6%
const float ROGUE_CHANCE = 0.05;      // -4.0%
const float HORIZON_CHANCE = 0.02;    // +10%
const float CLUSTER_CHANCE = 0.05;    // -1.6% globular, +0.7% open
const float GIANT_CHANCE = 0.05;      // +2-3%
const float MOON_CHANCE = 0.02;       // +15-20%

const float EVENT_WEIGHT_TOTAL = FIELD_CHANCE + COMETCLOSE_CHANCE + CRAB_CHANCE + RING_CHANCE +
    PLANET_CHANCE + COMET_CHANCE + ELLIPTICAL_CHANCE + BIPOLAR_CHANCE + PULSAR_CHANCE +
    SPIRAL_CHANCE + SYSTEM_CHANCE + STAR_CHANCE + PILLARS_CHANCE + BLACKHOLE_CHANCE +
    BINARY_CHANCE + EATEN_CHANCE + PULSARCLOSE_CHANCE + SUPERNOVA_CHANCE + SURFACE_CHANCE +
    COLLISION_CHANCE + QUASAR_CHANCE + ROGUE_CHANCE + HORIZON_CHANCE + CLUSTER_CHANCE +
    GIANT_CHANCE + MOON_CHANCE;

int pickEvent(float roll) {
    if (FORCE_EVENT >= 0) {
        return FORCE_EVENT;
    }
    // Spread the weights over the non-plain share of rolls; anything past them is plain sky.
    roll *= EVENT_WEIGHT_TOTAL / (1.0 - PLAIN_SKY_SHARE);
    float c = BLACKHOLE_CHANCE;
    if (roll < c) return EV_HOLE;
    c += STAR_CHANCE;
    if (roll < c) return EV_STAR;
    c += SYSTEM_CHANCE;
    if (roll < c) return EV_SYSTEM;
    c += COMET_CHANCE;
    if (roll < c) return EV_COMET;
    c += FIELD_CHANCE;
    if (roll < c) return EV_FIELD;
    c += PLANET_CHANCE;
    if (roll < c) return EV_PLANET;
    c += SPIRAL_CHANCE;
    if (roll < c) return EV_SPIRAL;
    c += ELLIPTICAL_CHANCE;
    if (roll < c) return EV_ELLIPTICAL;
    c += COMETCLOSE_CHANCE;
    if (roll < c) return EV_COMETCLOSE;
    c += BINARY_CHANCE;
    if (roll < c) return EV_BINARY;
    c += EATEN_CHANCE;
    if (roll < c) return EV_EATEN;
    c += PULSAR_CHANCE;
    if (roll < c) return EV_PULSAR;
    c += PULSARCLOSE_CHANCE;
    if (roll < c) return EV_PULSARCLOSE;
    c += SUPERNOVA_CHANCE;
    if (roll < c) return EV_SUPERNOVA;
    c += SURFACE_CHANCE;
    if (roll < c) return EV_SURFACE;
    c += COLLISION_CHANCE;
    if (roll < c) return EV_COLLISION;
    c += QUASAR_CHANCE;
    if (roll < c) return EV_QUASAR;
    c += ROGUE_CHANCE;
    if (roll < c) return EV_ROGUE;
    c += HORIZON_CHANCE;
    if (roll < c) return EV_HORIZON;
    c += GIANT_CHANCE;
    if (roll < c) return EV_GIANT;
    c += MOON_CHANCE;
    if (roll < c) return EV_MOON;
    c += CLUSTER_CHANCE;
    if (roll < c) return EV_CLUSTER;
    c += RING_CHANCE;
    if (roll < c) return EV_RING;
    c += PILLARS_CHANCE;
    if (roll < c) return EV_PILLARS;
    c += CRAB_CHANCE;
    if (roll < c) return EV_CRAB;
    c += BIPOLAR_CHANCE;
    if (roll < c) return EV_BIPOLAR;
    return EV_NONE;
}

// Seconds since the current event started (t is the wallpaper's total running time).
float eventTime(float t) {
    return t - floor(t / EVENT_PERIOD) * EVENT_PERIOD;
}

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

// Cosine colour palette: smooth, harmonious colours from a single number x.
vec3 pal(float x, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(6.28318 * (c * x + d));
}

// A random planet colour for hue x in [0, 1).
vec3 planetHue(float x) {
    return pal(x, vec3(0.6, 0.52, 0.47), vec3(0.32, 0.28, 0.28), vec3(1.0), vec3(0.0, 0.33, 0.67));
}

// 0 = cool red/orange, 0.5 = yellow-white, 1 = hot blue-white.
vec3 starColor(float k) {
    vec3 cool = vec3(1.0, 0.45, 0.18);
    vec3 mid = vec3(1.0, 0.93, 0.82);
    vec3 hot = vec3(0.62, 0.76, 1.0);
    return k < 0.5 ? mix(cool, mid, k * 2.0) : mix(mid, hot, (k - 0.5) * 2.0);
}

// "front over back" for premultiplied colours.
vec4 over(vec4 front, vec4 back) {
    return front + back * (1.0 - front.a);
}
