// Hanging just above a gas giant's rings, like Cassini's ring-plane views: we're a few thousand km
// over the outer rings, looking in at the planet. The rings are a vast translucent sheet of
// ringlets (dim C ring, bright B ring, the dark Cassini Division, A ring with the Encke Gap) that
// sweeps away beneath us, crosses in front of the planet's lower half - its clouds showing through
// the thinner bands - and arcs around behind its limb on both sides. The planet's shadow lies
// across the rings and the rings' shadow bands its clouds. Real 3D: each pixel's ray is tested
// against the ring plane and the planet, and whichever is nearer wins. Premultiplied colour/coverage.

const float RING_F = 0.95;  // focal length: a little wider than usual, the giant is huge

// Everything about the view that doesn't depend on the pixel: where we are, which way we look,
// the sun, and where the giant goes.
struct RingCam {
    vec3 C;
    float yaw, pitch, ringSc;
    vec3 L, Gw;
    GiantView gv;
};

RingCam ringPlaneCam(float seed, float slot, float t) {
    float lt = eventTime(t);
    const float f = RING_F;
    // Ring scale: the same as the giant renderer picks, so its ring shadows line up with ours.
    float ringSc = mix(0.92, 1.1, hash12(vec2(slot, seed + 515.0)));

    // Where we are (planet radius 1 at the origin, ring plane y = 0): over the outer rings, a
    // little above them, drifting very slowly along our orbit.
    float rc = ringSc * mix(2.15, 2.6, hash12(vec2(slot, seed + 701.0)));
    float hc = mix(0.12, 0.32, hash12(vec2(slot, seed + 703.0)));
    float az0 = hash12(vec2(slot, seed + 705.0)) * 6.2831 + eventDrift(lt) * 0.0004;
    vec3 C = vec3(rc * cos(az0), hc, rc * sin(az0));

    // Look toward the planet, turned so it sits off to one side, and tipped down so the rings
    // fill the lower part of the screen.
    vec3 toP = normalize(-C);
    float side = hash12(vec2(slot, seed + 707.0)) < 0.5 ? -1.0 : 1.0;
    float gA = asin(1.0 / length(C));                         // the planet's angular radius
    float yawOff = side * gA * mix(0.1, 0.4, hash12(vec2(slot, seed + 709.0)));
    vec2 fw = rotate(yawOff) * normalize(toP.xz);
    float yaw = atan(-fw.x, -fw.y);
    float elC = asin(toP.y);                                  // planet centre's elevation (< 0)
    float pitch = elC - atan(mix(0.0, 0.1, hash12(vec2(slot, seed + 711.0))) / f);

    // Sun: above the ring plane (we see the rings' lit face), on our side of the planet so its
    // face is mostly lit; sometimes far enough round that its shadow falls across the rings.
    float sEl = mix(0.12, 0.45, hash12(vec2(slot, seed + 713.0)));
    vec2 sxz = rotate((hash12(vec2(slot, seed + 715.0)) < 0.5 ? -1.0 : 1.0) * mix(1.9, 2.8, hash12(vec2(slot, seed + 717.0)))) * normalize(toP.xz);
    vec3 L = vec3(sxz.x * cos(sEl), sin(sEl), sxz.y * cos(sEl));

    // The giant, through the shared renderer: centre and size on screen, sun direction in its view
    // frame, and its pole tipped toward us by our height above the ring plane.
    vec3 Gw = toP;
    vec3 Gc = moonRx(moonRy(Gw, -yaw), pitch);
    vec2 gCenter = f * Gc.xy / -Gc.z;
    // Off-axis, perspective makes the planet look a little bigger.
    float gR = f * tan(gA) / max(-Gc.z, 0.5);
    vec3 zg = -Gc;
    vec3 xg = normalize(cross(vec3(0.0, 1.0, 0.0), zg));
    vec3 yg = cross(zg, xg);
    vec3 Lc = moonRx(moonRy(L, -yaw), pitch);
    RingCam rc0;
    rc0.C = C; rc0.yaw = yaw; rc0.pitch = pitch; rc0.ringSc = ringSc;
    rc0.L = L; rc0.Gw = Gw;
    rc0.gv = GiantView(gCenter, gR, vec3(dot(Lc, xg), dot(Lc, yg), dot(Lc, zg)), vec4(-elC, 0.0, 1.0, 1.0), 1.0);
    return rc0;
}

// cam: the view set-up; giant/gTint: the giant, already drawn by the shared renderer.
vec4 ringPlane(vec2 uv, float seed, float slot, float t, float fade, RingCam cam, vec4 giant, vec3 gTint) {
    const float f = RING_F;
    vec3 C = cam.C;
    float ringSc = cam.ringSc;
    vec3 L = cam.L;
    vec3 rd = moonRy(moonRx(normalize(vec3(uv, -f)), -cam.pitch), cam.yaw);
    vec3 sunC = vec3(1.0, 0.97, 0.92) * 0.75;
    // Light the giant's day side throws back onto the rings.
    vec3 gShine = gTint * (0.5 + 0.5 * dot(L, -cam.Gw)) * 0.06;

    // Distance along the ray to the ring plane.
    float tR = rd.y < 0.0 ? C.y / -rd.y : 1e9;
    // Computed for every pixel so its derivatives (used to fade detail too fine to draw) are valid.
    vec3 Pw = C + rd * min(tR, 50.0);
    float rho = length(Pw.xz);
    float fwr = max(fwidth(rho), 1e-6);

    vec4 ring = vec4(0.0);
    if (tR < 1e8 && rho < 2.45 * ringSc) {
        float op = giantRings(rho, fwr, ringSc, seed, 0);
        float x = rho / ringSc;
        // Ringlets: fine radial structure at several scales, each fading once narrower than a pixel.
        float r1 = noise(vec2(rho * 900.0, seed + 11.0));
        float r2 = noise(vec2(rho * 3500.0, seed + 23.0));
        float r3 = noise(vec2(rho * 12000.0, seed + 37.0));
        float k1 = smoothstep(1.0, 0.3, fwr * 900.0);
        float k2 = smoothstep(1.0, 0.3, fwr * 3500.0);
        float k3 = smoothstep(1.0, 0.3, fwr * 12000.0);
        float fine = 1.0 + (r1 - 0.5) * 0.5 * k1 + (r2 - 0.5) * 0.4 * k2 + (r3 - 0.5) * 0.3 * k3;
        op = clamp(op * fine, 0.0, 0.995);
        // Seen at a slant, the line of sight crosses more of the ring: more opaque.
        // (Capped, so the thin C ring stays see-through.)
        float a = min(1.0 - pow(1.0 - op, 1.0 / max(-rd.y, 0.03)), 0.3 + op);
        // Colour: the C ring dark and grey-brown, the B ring bright cream-tan, the A ring a little
        // greyer, with faint colour banding.
        vec3 rcol = mix(vec3(0.5, 0.46, 0.42), vec3(0.95, 0.86, 0.7), smoothstep(1.45, 1.6, x));
        rcol = mix(rcol, vec3(0.82, 0.77, 0.7), smoothstep(1.97, 2.06, x));
        // Ringlet to ringlet the ice is subtly different: tan, pinkish, grey.
        float tintN = noise(vec2(rho * 70.0, seed + 5.0));
        rcol *= mix(vec3(1.05, 0.97, 0.88), vec3(0.92, 0.95, 1.02), tintN) * (0.85 + 0.3 * noise(vec2(rho * 260.0, seed + 9.0)));
        // Denser ring reflects more light: the B ring blazes, the Cassini Division is nearly black.
        rcol *= 0.2 + 1.1 * pow(op, 1.3);
        // Lit face, with the planet's shadow lying across the rings.
        float lit = 0.1 + 1.2 * sqrt(L.y);
        vec3 Pr = C + rd * tR;
        float tc = -dot(Pr, L);
        float shade = 1.0;
        if (tc > 0.0) {
            shade = smoothstep(0.97, 1.03, length(Pr + L * tc));
        }
        vec3 c = rcol * (sunC * lit * mix(0.02, 1.0, shade) + gShine);
        ring = vec4(c * a, a);
    }

    // Ring nearer than the planet's centre goes in front of it (crossing its lower half), farther
    // ring behind. The planet's coverage is its drawn disc, so the two always line up.
    float ringDepth = dot(C + rd * min(tR, 50.0) - C, cam.Gw);
    vec4 res = ringDepth < length(C) ? over(ring, giant) : over(giant, ring);
    return res * fade;
}
