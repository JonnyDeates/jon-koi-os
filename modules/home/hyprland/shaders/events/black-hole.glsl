// Ray-traced black hole geometry. Inside the trace, distances are in Schwarzschild radii; on
// screen the shadow has radius R.
const float B_CRIT = 2.598;       // shadow radius in Schwarzschild radii (3*sqrt(3)/2)
// Rays start, and stop once heading away, just outside the disk's outer edge (11 R ≈ 29 Rs):
// beyond that nothing more can be hit and the remaining bending is negligible.
const float CAM_DIST = 33.0;
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
    center += (hash22(vec2(slot, seed + 47.0)) - 0.5) * 0.0004 * eventDrift(lt);
    float tilt = (hash12(vec2(slot, seed + 53.0)) - 0.5) * 0.35;
    // Camera a few degrees above the disk plane: usually nearly edge-on like in the film,
    // sometimes tilted a bit more so more of the disk's face shows.
    float incl = mix(0.035, 0.15, pow(hash12(vec2(slot, seed + 59.0)), 2.0));
    float spinDir = hash12(vec2(slot, seed + 61.0)) < 0.5 ? -1.0 : 1.0;
    float spin = spinDir * mix(0.2, 0.5, hash12(vec2(slot, seed + 65.0)));
    float outerR = mix(7.0, 11.0, hash12(vec2(slot, seed + 67.0)));

    // Disk temperature: the classic gold most often, otherwise white-hot, blue-tinted or deep orange.
    float temp = hash12(vec2(slot, seed + 63.0));
    vec3 dustC = DISK_DUST;
    vec3 midC = DISK_AMBER;
    vec3 hotC = DISK_WHITE;
    if (temp > 0.86) {
        dustC = vec3(0.25, 0.06, 0.02); midC = vec3(1.0, 0.42, 0.12); hotC = vec3(1.0, 0.75, 0.45);
    } else if (temp > 0.72) {
        dustC = vec3(0.1, 0.1, 0.18); midC = vec3(0.75, 0.8, 1.0); hotC = vec3(0.92, 0.96, 1.0);
    } else if (temp > 0.55) {
        dustC = vec3(0.25, 0.15, 0.1); midC = vec3(1.0, 0.85, 0.7); hotC = vec3(1.0, 0.98, 0.95);
    }

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
            if (r < 1.0 || (r > CAM_DIST && dot(pos, vel) > 0.0)) {
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
                    // Doppler beaming: gas coming toward us is brighter, gas moving away dimmer.
                    hitBeam[hits] = pow(1.0 + 0.32 * dot(orbit, -normalize(vel)), 2.5);
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
            vec4 s = diskSample(hitRho[k], hitDir[k], t, spin, seed, fpRho, fpDir, outerR, dustC, midC, hotC);
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
