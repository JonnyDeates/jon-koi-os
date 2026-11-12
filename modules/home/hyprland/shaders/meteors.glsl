// Shooting stars, drawn over every scene. Each monitor has a chance of a meteor shower in each
// SHOWER_PERIOD window: for SHOWER_LENGTH seconds, meteors all streak across in the same direction. Outside
// showers a lone, sporadic meteor crosses now and then. Each meteor is a bright head with a fading,
// glowing trail and a slight tint; some are fireballs that flare and break apart. How long they last
// varies a lot: most are quick flashes, some slow, and a few leave a persistent train that hangs in
// the sky and slowly fades after the head has gone. Additive light.

const float SHOWER_PERIOD = 300.0;
const float SHOWER_CHANCE = 0.35;
const float SHOWER_LENGTH = 25.0;
const float METEOR_SLOT = 4.0;    // each lane can start a new meteor this often
const int METEOR_LANES = 10;

// One meteor travelling from p0 along dir; age runs 0 -> 1 while the head crosses, then up to
// 1 + linger while a persistent train fades.
vec3 meteorLight(vec2 uv, vec2 p0, vec2 dir, float len, float age, float linger, float bright, vec3 tint,
                 bool fireball, float hm) {
    float after = max(age - 1.0, 0.0) / max(linger, 1e-4);  // 0..1 through the train's fade
    age = min(age, 1.0);
    vec2 head = p0 + dir * len * age;
    vec2 rel = uv - head;
    float along = -dot(rel, dir);                 // > 0 behind the head
    float across = dot(rel, vec2(-dir.y, dir.x));
    float ps = pxScale() / minDim();
    float trailLen = len * 0.6 * min(age * 2.5, 1.0);
    // Brightness swells then fades over its life; fireballs flare near the end.
    float life = smoothstep(0.0, 0.15, age) * smoothstep(1.0, 0.6, age);
    if (fireball) {
        life *= 1.0 + 2.5 * exp(-pow((age - 0.7) / 0.08, 2.0));
    }
    float w = ps * (fireball ? 3.0 : 1.8);
    float spread = 1.0 + max(along, 0.0) / max(trailLen, 1e-4) * 3.0; // trail widens behind the head
    float trail = exp(-across * across / (w * w * spread))
            * exp(-max(along, 0.0) / max(trailLen, 1e-4) * 1.8) * step(0.0, along + w);
    float headGlow = exp(-dot(rel, rel) / (w * w * 4.0)) * 1.5 + exp(-length(rel) / (w * 8.0)) * 0.3;
    vec3 col = (mix(tint, vec3(1.0), 0.4) * trail * 1.6 + vec3(1.0) * headGlow) * life * bright;
    if (linger > 0.0 && after > 0.0) {
        // Persistent train: the glowing path stays, spreading out and fading with a little drift.
        float behind = clamp(dot(uv - p0, dir) / len, 0.0, 1.0);
        float trAcross = dot(uv - p0, vec2(-dir.y, dir.x)) + (noise(vec2(behind * 8.0, hm * 9.0)) - 0.5) * 0.01 * after;
        float tw = w * (1.5 + 10.0 * after);
        // Tapers off at both ends instead of stopping at a hard line.
        float s = dot(uv - p0, dir) / len;
        float train = exp(-trAcross * trAcross / (tw * tw)) * smoothstep(0.0, 0.3, s) * smoothstep(1.05, 0.8, s)
                * (1.0 - after) * (1.0 - after) / (1.0 + 4.0 * after);
        col += mix(tint, vec3(0.7, 1.0, 0.8), 0.5) * train * 0.7 * bright;
    }
    if (fireball && age > 0.7) {
        // Fragments peeling off behind the head after it breaks up.
        for (int i = 0; i < 4; i++) {
            float hi = hash12(vec2(hm, float(i)));
            vec2 off = dir * (-0.01 - hi * 0.03) * (age - 0.7) / 0.3 + vec2(-dir.y, dir.x) * (hi - 0.5) * 0.02 * (age - 0.7) / 0.3;
            float fd = length(uv - head - off);
            col += tint * exp(-fd * fd / (w * w * 2.0)) * smoothstep(1.0, 0.75, age) * bright * 0.8;
        }
    }
    return col;
}

// Whether a meteor shower is under way at time tm, and which way its meteors fly.
bool meteorShower(float tm, float seed, out vec2 showerDir) {
    float window = floor(tm / SHOWER_PERIOD);
    float inWindow = tm - window * SHOWER_PERIOD;
    bool shower = hash12(vec2(window, seed + 401.0)) < SHOWER_CHANCE;
    float showerStart = hash12(vec2(window, seed + 403.0)) * (SHOWER_PERIOD - SHOWER_LENGTH);
    // Every meteor in a shower travels the same way (a few degrees of spread), mostly downward.
    float showerAng = -1.5708 + (hash12(vec2(window, seed + 405.0)) - 0.5) * 2.4;
    showerDir = vec2(cos(showerAng), sin(showerAng));
    return shower && inWindow > showerStart && inWindow < showerStart + SHOWER_LENGTH;
}

vec3 meteors(vec2 uv, float seed, float t) {
    vec2 ext = halfExtent();
    vec3 col = vec3(0.0);
    for (int i = 0; i < METEOR_LANES; i++) {
        float lane = float(i);
        float laneT = t + lane * 0.73;
        // A lane starts a meteor every METEOR_SLOT seconds, but a slow one with a lingering train
        // can outlast its slot: keep drawing the previous slot's meteor until it has faded.
        for (int k = 0; k < 2; k++) {
            float slot = floor(laneT / METEOR_SLOT) - float(k);
            // Shower or not is decided by when this meteor started, so ones already in flight
            // finish when a shower ends.
            vec2 showerDir;
            bool showerOn = meteorShower(slot * METEOR_SLOT - lane * 0.73, seed, showerDir);
            float hm = hash12(vec2(slot * 7.0 + lane, seed + 407.0));
            // During a shower most slots fire; otherwise only the first lane, rarely (sporadic meteors).
            float chance = showerOn ? 0.45 : (i == 0 ? 0.044 : 0.0);
            if (hm > chance) {
                continue;
            }
            // Most are quick flashes, some slow; a few slow bright ones leave a persistent train.
            float durPick = hash12(vec2(hm, 1.0));
            float dur = durPick < 0.65 ? mix(0.25, 0.7, durPick / 0.65) : mix(1.0, 2.0, (durPick - 0.65) / 0.35);
            float linger = hash12(vec2(hm, 10.0)) < (dur > 1.0 ? 0.45 : 0.08) ? mix(1.5, 3.0, hash12(vec2(hm, 11.0))) / dur : 0.0;
            float age = (laneT - slot * METEOR_SLOT) / dur;
            if (age > 1.0 + linger) {
                continue;
            }
            vec2 start;
            vec2 dir;
            if (showerOn) {
                // Starts anywhere on screen, shifted back upstream so it streaks across it.
                dir = rotate((hash12(vec2(hm, 2.0)) - 0.5) * 0.12) * showerDir;
                start = (hash22(vec2(hm, 3.0)) - 0.5) * 2.0 * ext * 0.9 - dir * 0.15;
            } else {
                start = (hash22(vec2(hm, 4.0)) - 0.5) * 2.0 * ext * 0.8;
                float a = hash12(vec2(hm, 5.0)) * 6.2831;
                dir = vec2(cos(a), sin(a));
            }
            float len = mix(0.15, 0.45, hash12(vec2(hm, 6.0)));
            bool fireball = hash12(vec2(hm, 7.0)) < 0.08;
            float tintPick = hash12(vec2(hm, 8.0));
            vec3 tint = tintPick < 0.5 ? vec3(0.75, 1.0, 0.8) : tintPick < 0.8 ? vec3(0.9, 0.92, 1.0) : vec3(1.0, 0.75, 0.45);
            float bright = mix(0.5, 1.2, hash12(vec2(hm, 9.0))) * (fireball ? 1.6 : 1.0);
            col += meteorLight(uv, start, dir, len, age, linger, bright, tint, fireball, hm);
        }
    }
    return col;
}
