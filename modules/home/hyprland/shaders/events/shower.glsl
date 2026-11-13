// A meteor shower lasting the whole scene, over the plain sky. Every meteor flies out from one
// radiant far off screen, so they all run nearly the same way, fanning out only slightly. They
// streak a long way across the sky at speeds that vary a lot, from brisk to slow crawls lasting
// several seconds, and some of the bright ones leave a train that hangs and fades. The rate rises
// and falls over the half hour, with a couple of outbursts. Additive light; needs meteors.glsl.

const int SHOWER_LANES = 24;
const float SHOWER_SLOT = 2.5;   // each lane can start a meteor this often
const int SHOWER_LOOKBACK = 4;   // slots a slow meteor and its train can stay up (10 s)

vec3 meteorShower(vec2 uv, float seed, float slot, float t, float fade) {
    float lt = eventTime(t);
    vec2 ext = halfExtent();

    // The radiant: far off screen and above, so the meteors' paths are close to parallel and
    // they fall down across the sky at a slant.
    float ra = 1.5708 + (hash12(vec2(slot, seed + 421.0)) - 0.5) * 2.4;
    float rr = mix(5.0, 8.0, hash12(vec2(slot, seed + 423.0)));
    vec2 radiant = vec2(cos(ra), sin(ra)) * ext * rr;

    // Activity over the scene: a slow swell, plus two outbursts of a minute or so.
    float ph = hash12(vec2(slot, seed + 425.0)) * 6.2831;
    float act = 0.55 + 0.3 * sin(lt / EVENT_PERIOD * 6.2831 + ph);
    for (int k = 0; k < 2; k++) {
        float tb = mix(0.1, 0.9, hash12(vec2(slot, seed + 427.0 + float(k)))) * EVENT_PERIOD;
        act += 0.9 * exp(-pow((lt - tb) / 50.0, 2.0));
    }

    vec3 col = vec3(0.0);
    for (int i = 0; i < SHOWER_LANES; i++) {
        float lane = float(i);
        float laneT = t + lane * 0.61;
        for (int k = 0; k < SHOWER_LOOKBACK; k++) {
            float ms = floor(laneT / SHOWER_SLOT) - float(k);
            float hm = hash12(vec2(ms * 7.0 + lane, seed + 431.0));
            if (hm > 0.37 * act) {
                continue;
            }
            // Where it appears, flying straight away from the radiant, and how far it streaks.
            vec2 p0 = (hash22(vec2(hm, 3.0)) - 0.5) * 2.0 * ext * 0.95;
            vec2 dir = normalize(p0 - radiant);
            float len = mix(0.3, 0.9, hash12(vec2(hm, 6.0)));
            p0 -= dir * len * 0.4;
            // Speed in screen heights per second, spread evenly from brisk (0.7) to a slow crawl
            // (0.1); how long it takes to cross follows from that.
            float speed = exp(mix(log(0.1), log(0.7), hash12(vec2(hm, 1.0))));
            float dur = min(len / speed, 8.0);
            // Bright fast ones sometimes leave a train.
            float linger = hash12(vec2(hm, 10.0)) < (dur < 1.5 ? 0.12 : 0.05) ? mix(1.5, 4.0, hash12(vec2(hm, 11.0))) : 0.0;
            float span = min(dur + linger, SHOWER_SLOT * float(SHOWER_LOOKBACK) - 0.1);
            linger = max(span - dur, 0.0) / dur;
            float age = (laneT - ms * SHOWER_SLOT) / dur;
            if (age > 1.0 + linger) {
                continue;
            }
            // Skip pixels nowhere near its path (the head glow and train are only a few px wide).
            vec2 rel = uv - p0;
            float along = clamp(dot(rel, dir), 0.0, len);
            if (length(rel - dir * along) > 0.07) {
                continue;
            }
            bool fireball = hash12(vec2(hm, 7.0)) < 0.05;
            // Quick ones are brighter; the slow ones glow more softly.
            float bright = mix(0.45, 1.25, hash12(vec2(hm, 9.0))) * mix(0.7, 1.2, smoothstep(0.15, 0.6, len / dur))
                         * (fireball ? 1.6 : 1.0);
            col += meteorLight(uv, p0, dir, len, age, linger, bright, meteorTint(hash12(vec2(hm, 8.0))), fireball, hm);
        }
    }
    return col * fade;
}
