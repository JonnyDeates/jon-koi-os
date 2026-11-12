// Gas giant close-up, like Cassini's Saturn or Juno's Jupiter: a huge planet filling much of the
// screen. Its cloud bands flow at different speeds, so they shear and roil against each other, and
// oval storms slowly spin. Some have rings - Saturn-like, with the Cassini division, Encke gap and
// thin F ring; or a few narrow dark ringlets like Uranus. The planet's shadow falls across the
// rings and the rings' shadow across the clouds; seen from the unlit side, thin rings glow and the
// dense ones go dark. A small moon circles in the ring plane, passing in front of or behind the
// planet and dropping its shadow on the clouds. Along the band edges, chains of small eddies curl
// the clouds into waves and hooks. Premultiplied colour/coverage.

float giantHash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

float giantNoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = mix(mix(giantHash(i), giantHash(i + vec3(1, 0, 0)), f.x),
                  mix(giantHash(i + vec3(0, 1, 0)), giantHash(i + vec3(1, 1, 0)), f.x), f.y);
    float b = mix(mix(giantHash(i + vec3(0, 0, 1)), giantHash(i + vec3(1, 0, 1)), f.x),
                  mix(giantHash(i + vec3(0, 1, 1)), giantHash(i + vec3(1, 1, 1)), f.x), f.y);
    return mix(a, b, f.z);
}

float giantFbm(vec3 p, int oct) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        if (i >= oct) {
            break;
        }
        v += a * giantNoise(p);
        p = p * 2.03 + vec3(1.7, 9.2, 4.1);
        a *= 0.5;
    }
    return v;
}

// One layer of small vortices: each cell holds an eddy that turns the flow around its centre,
// strongest in the middle and fading to nothing well inside the cell, so cells join seamlessly.
// Each slowly winds up over the event. Returns the displacement, in cell units.
vec2 giantEddy(vec2 q, float seed, float lt) {
    vec2 id = floor(q);
    vec2 o = fract(q) - (0.5 + (hash22(id + seed) - 0.5) * 0.3);
    float fall = smoothstep(0.35, 0.0, length(o));
    float h = hash12(id + seed + 3.7);
    float spin = (h < 0.5 ? -1.0 : 1.0) * (1.5 + 2.0 * h + lt * 0.012) * fall * fall;
    return rotate(spin) * o - o;
}

// How opaque the rings are at distance rho (in planet radii). kind 0 = Saturn-like, 1 = narrow.
// fw is how much rho changes per pixel, so fine ringlets fade out instead of shimmering.
float giantRings(float rho, float fw, float sc, float seed, int kind) {
    float e = max(fw, 0.002);
    if (kind == 1) {
        float op = 0.0;
        for (int i = 0; i < 6; i++) {
            float ri = sc * mix(1.55, 2.05, (float(i) + hash12(vec2(float(i), seed + 501.0)) * 0.6) / 6.0);
            float wi = max(0.003 + 0.004 * hash12(vec2(float(i), seed + 503.0)), e);
            op += exp(-pow((rho - ri) / wi, 2.0)) * 0.5 * (0.004 / wi + 0.3);
        }
        return clamp(op, 0.0, 0.8);
    }
    float x = rho / sc;
    float op = smoothstep(1.11, 1.13, x) * smoothstep(1.24, 1.22, x) * 0.04;            // D ring
    op += smoothstep(1.24 - e, 1.24 + e, x) * smoothstep(1.53 + e, 1.53 - e, x)
        * (0.12 + 0.08 * smoothstep(1.3, 1.5, x));                                       // C ring
    op += smoothstep(1.53 - e, 1.53 + e, x) * smoothstep(1.95 + e, 1.95 - e, x)
        * mix(0.65, 0.97, smoothstep(1.53, 1.75, x));                                    // B ring
    op += smoothstep(1.95, 2.03, x) * smoothstep(2.03 + e, 2.03 - e, x) * 0.05;          // Cassini division
    float aRing = smoothstep(2.03 - e, 2.03 + e, x) * smoothstep(2.27 + e, 2.27 - e, x) * 0.5;
    aRing *= mix(1.0, 0.1, exp(-pow((x - 2.215) / max(0.004, e), 2.0)));                // Encke gap
    op += aRing;
    op += exp(-pow((x - 2.33) / max(0.004, e), 2.0)) * 0.45;                            // F ring
    // Ringlets at many scales; finer ones average out where they'd be smaller than a pixel.
    float fine = clamp(1.0 - fw * 300.0, 0.0, 1.0);
    float mid = clamp(1.0 - fw * 60.0, 0.0, 1.0);
    op *= mix(1.0, 0.75 + 0.5 * noise(vec2(x * 60.0, seed)), mid);
    op *= mix(1.0, 0.7 + 0.6 * noise(vec2(x * 320.0, seed + 7.0)), fine);
    return clamp(op, 0.0, 0.98);
}

// The planet itself, centred at center with screen radius R, lit from direction L (z toward us).
// tint returns its overall colour, for light it throws on things nearby.
vec4 giantBody(vec2 uv, vec2 center, float R, vec3 L, float seed, float slot, float lt, out vec3 tint) {
    float pick = hash12(vec2(slot, seed + 511.0));
    // Palette: zone (light bands), belt (dark bands), accent (storms), polar haze, turbulence.
    vec3 zone, belt, accent, polar;
    float turb, contrast;
    int kindP;
    if (pick < 0.28) {          // Jupiter-like
        zone = vec3(0.93, 0.87, 0.76); belt = vec3(0.6, 0.42, 0.3); accent = vec3(0.8, 0.38, 0.22);
        polar = vec3(0.5, 0.52, 0.58); turb = 1.0; contrast = 1.0; kindP = 0;
    } else if (pick < 0.56) {   // Saturn-like
        zone = vec3(0.93, 0.85, 0.66); belt = vec3(0.78, 0.66, 0.47); accent = vec3(0.97, 0.93, 0.8);
        polar = vec3(0.55, 0.62, 0.66); turb = 0.45; contrast = 0.7; kindP = 1;
    } else if (pick < 0.70) {   // Neptune-like
        zone = vec3(0.3, 0.5, 0.95); belt = vec3(0.17, 0.29, 0.72); accent = vec3(0.93, 0.96, 1.0);
        polar = vec3(0.25, 0.4, 0.85); turb = 0.6; contrast = 0.8; kindP = 2;
    } else if (pick < 0.80) {   // Uranus-like
        zone = vec3(0.66, 0.88, 0.92); belt = vec3(0.58, 0.8, 0.86); accent = vec3(0.85, 0.96, 0.98);
        polar = vec3(0.75, 0.92, 0.95); turb = 0.15; contrast = 0.4; kindP = 3;
    } else if (pick < 0.90) {   // hot, rusty giant
        zone = vec3(0.92, 0.55, 0.38); belt = vec3(0.45, 0.16, 0.18); accent = vec3(1.0, 0.8, 0.45);
        polar = vec3(0.4, 0.2, 0.25); turb = 0.9; contrast = 1.0; kindP = 4;
    } else {                    // violet giant
        zone = vec3(0.78, 0.68, 0.96); belt = vec3(0.4, 0.3, 0.66); accent = vec3(0.96, 0.88, 1.0);
        polar = vec3(0.35, 0.3, 0.6); turb = 0.7; contrast = 0.85; kindP = 5;
    }
    float ringRoll = hash12(vec2(slot, seed + 513.0));
    // Ringed: almost always for Saturn-likes, often narrow ringlets for Uranus-likes, sometimes others.
    int ringKind = -1;
    if (kindP == 1) {
        if (ringRoll < 0.95) ringKind = 0;
    } else if (kindP == 3) {
        if (ringRoll < 0.7) ringKind = 1;
    } else if (ringRoll < 0.25) {
        ringKind = 0;
    } else if (ringRoll < 0.45) {
        ringKind = 1;
    }
    float ringSc = mix(0.92, 1.1, hash12(vec2(slot, seed + 515.0)));
    tint = mix(zone, belt, 0.35);

    // Pole: tipped toward or away from us, and rolled on screen.
    float tip = mix(0.1, 0.42, hash12(vec2(slot, seed + 523.0))) * (hash12(vec2(slot, seed + 525.0)) < 0.5 ? -1.0 : 1.0);
    float roll = (hash12(vec2(slot, seed + 527.0)) - 0.5) * 0.9;
    vec3 P = vec3(0.0, cos(tip), sin(tip));
    P.xy = rotate(roll) * P.xy;
    vec3 Q = normalize(cross(P, vec3(0.0, 0.0, 1.0)));
    vec3 F = cross(Q, P);

    vec2 d = (uv - center) / R;
    float r = length(d);
    float px = 1.5 / (R * minDim());

    // Ring plane hit (everywhere, so derivatives stay valid): X . P = 0 along the view ray.
    float zr = -(d.x * P.x + d.y * P.y) / P.z;
    vec3 X = vec3(d, zr);
    float rho = length(X);
    float fw = fwidth(rho);

    vec4 planetL = vec4(0.0);
    float zPlanet = -1e3;
    vec4 ringL = vec4(0.0);
    float zRing = zr;
    vec4 moonL = vec4(0.0);

    // Moon, circling in the ring plane outside the rings.
    float mA = mix(2.6, 3.4, hash12(vec2(slot, seed + 533.0))) * (ringKind == 0 ? ringSc : 0.8);
    float mTh = hash12(vec2(slot, seed + 535.0)) * 6.2831 + lt * 0.012;
    vec3 M = (Q * cos(mTh) + F * sin(mTh)) * mA;
    float mR = mix(0.035, 0.07, hash12(vec2(slot, seed + 537.0)));

    if (r < 1.0 + px) {
        float z = sqrt(max(1.0 - r * r, 0.0));
        vec3 N = vec3(d, z);
        float sLat = dot(N, P);
        // Differential rotation: alternating jets, a fast equatorial current.
        float nb = mix(6.0, 9.0, hash12(vec2(slot, seed + 539.0)));
        // Kept small so over an event the bands slide past each other without shredding the clouds.
        float u = (0.0012 * sin(sLat * nb * 3.1416) + 0.002 * exp(-sLat * sLat / 0.02)) * mix(0.6, 1.0, turb);
        float a0 = lt * 0.006;
        float ang = a0 + eventDrift(lt) * u;
        vec3 pf = vec3(dot(N, Q), sLat, dot(N, F));
        vec3 pr = vec3(pf.x * cos(ang) - pf.z * sin(ang), pf.y, pf.x * sin(ang) + pf.z * cos(ang));
        // Storms ride with the planet's overall spin, so they keep their shape.
        vec3 pr0 = vec3(pf.x * cos(a0) - pf.z * sin(a0), pf.y, pf.x * sin(a0) + pf.z * cos(a0));

        // Storms: one big oval and a few smaller ones, each spinning slowly.
        vec3 sw = vec3(0.0);
        float stormC = 0.0;
        float collar = 0.0;
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float big = i == 0 ? 1.0 : 0.0;
            float slat = (hash12(vec2(fi, seed + 541.0 + slot)) - 0.5) * 1.3;
            float slon = hash12(vec2(fi, seed + 543.0 + slot)) * 6.2831;
            float sz = mix(0.05, 0.09, hash12(vec2(fi, seed + 545.0))) * (big > 0.0 ? 2.2 : 1.0);
            if (i > 0 && hash12(vec2(fi, seed + 547.0 + slot)) < 0.3) {
                continue;
            }
            float cl = sqrt(1.0 - slat * slat);
            vec3 sc = vec3(cl * sin(slon), slat, cl * cos(slon));
            vec3 east = normalize(vec3(cos(slon), 0.0, -sin(slon)));
            vec3 north = cross(sc, east);
            vec3 rel = pr0 - sc;
            if (dot(pr0, sc) < 0.0) {
                continue;
            }
            vec2 q = vec2(dot(rel, east), dot(rel, north)) / (sz * vec2(1.8, 1.0));
            float rr = dot(q, q);
            float fall = exp(-rr * 1.2);
            float swirl = (1.5 + 2.0 * fall) * fall * (hash12(vec2(fi, seed + 549.0)) < 0.5 ? -1.0 : 1.0) + eventDrift(lt) * 0.02 * fall;
            vec2 qs = rotate(swirl) * q;
            sw += (east * qs.x * 1.8 + north * qs.y - east * q.x * 1.8 - north * q.y) * sz * fall;
            stormC = max(stormC, smoothstep(1.0, 0.3, rr) * (0.6 + 0.4 * big));
            // A pale collar of cloud wrapped around the big storm.
            collar = max(collar, big * exp(-pow((sqrt(rr) - 1.12) / 0.2, 2.0)));
        }
        vec3 ps = pr + sw;

        // Eddies: chains of small vortices rolling along the band edges, where neighbouring jets
        // shear past each other, curling the edges into waves and hooks. Two sizes.
        float edge0 = noise(vec2(ps.y * 10.0, seed));
        float edgeMask = (1.0 - smoothstep(0.06, 0.24, abs(edge0 - 0.5))) * turb;
        if (edgeMask > 0.0) {
            float lon = atan(ps.x, ps.z);
            // Whole numbers of cells around the planet, so there's no seam.
            vec2 e = giantEddy(vec2(lon * 44.0 / 6.2832, ps.y * 14.0), seed, eventDrift(lt)) / vec2(44.0 / 6.2832, 14.0)
                   + giantEddy(vec2(lon * 150.0 / 6.2832, ps.y * 52.0), seed + 7.0, eventDrift(lt)) / vec2(150.0 / 6.2832, 52.0) * 0.7;
            e *= edgeMask;
            float cl = length(ps.xz);
            ps = vec3(sin(lon + e.x) * cl, ps.y + e.y, cos(lon + e.x) * cl);
        }

        // Bands: irregular light zones and dark belts, edges churned by turbulence that's
        // strongest where neighbouring jets shear past each other.
        float shear = abs(cos(sLat * nb * 3.1416));
        float w1 = giantFbm(ps * vec3(2.2, 9.0, 2.2) + seed, 5) - 0.5;
        float w2 = giantFbm(ps * vec3(5.0, 22.0, 5.0) - seed + vec3(lt * 0.004, 0.0, lt * 0.006), 4) - 0.5;
        // A second warp fed by the first curls the flow into finer filaments.
        float w3 = giantFbm(ps * vec3(9.0, 34.0, 9.0) + vec3(w1, w2, w1) * 3.0 + seed * 3.0, 4) - 0.5;
        float warp = (w1 * (0.6 + 0.8 * shear) + w2 * 0.5) * turb;
        float lat = ps.y + warp * 0.08 + w3 * 0.03 * turb;
        float bandA = noise(vec2(lat * 10.0, seed));
        float bandB = noise(vec2(lat * 34.0, seed + 5.0));
        float zoneAmt = smoothstep(0.38, 0.62, bandA) * 0.75 + bandB * 0.25;
        zoneAmt = mix(0.5, zoneAmt, contrast);
        vec3 c = mix(belt, zone, zoneAmt);
        // Belts are mottled: darker knots and lighter rifts in the turbulence.
        c = mix(c, c * mix(0.7, 1.25, smoothstep(-0.25, 0.25, w3)), (1.0 - zoneAmt) * 0.7 * turb);
        // Fine streaky texture along the flow.
        float streak = giantFbm(ps * vec3(7.0, 42.0, 7.0) + vec3(warp * 2.0 + w3, 0.0, 0.0) + seed * 2.0, 3);
        c *= 0.88 + 0.24 * streak * (0.4 + 0.6 * turb);
        // Zones carry puffy, brighter cloud tops.
        c = mix(c, mix(zone, vec3(1.0), 0.2), smoothstep(0.02, 0.28, w3) * zoneAmt * 0.35 * turb);
        // Storms: the big one takes the accent, small ones are pale ovals, both with the swirling
        // cloud texture showing through; a pale collar rings the big one.
        c = mix(c, mix(zone, vec3(1.0), 0.15), collar * 0.55);
        c = mix(c, accent * (0.7 + 0.6 * streak + 0.4 * w3), stormC * 0.75);
        // Hazy poles.
        c = mix(c, polar, smoothstep(0.7, 0.92, abs(sLat)) * 0.8);

        // Lighting: soft terminator, darker toward the limb.
        float mu = dot(N, L);
        float day = smoothstep(-0.06, 0.3, mu);
        float lambert = max(mu, 0.0);
        float limb = 0.55 + 0.45 * sqrt(z);
        vec3 lit = c * (0.015 + 1.15 * mix(lambert, sqrt(lambert), 0.4) * day) * limb;
        // Shadow of the rings on the clouds.
        if (ringKind >= 0) {
            float s = -dot(N, P) / dot(L, P);
            if (s > 0.0) {
                vec3 Y = N + L * s;
                lit *= 1.0 - 0.85 * giantRings(length(Y), 0.01, ringSc, seed, ringKind);
            }
            // Ringshine: the hemisphere facing the rings' sunlit face glows faintly at night.
            float faceLit = sign(dot(L, P));
            lit += c * 0.025 * (1.0 - day) * smoothstep(0.0, 0.5, sLat * faceLit);
        }
        // Moon shadow.
        vec3 toM = M - N;
        float along = dot(toM, L);
        if (along > 0.0) {
            float off = length(toM - L * along);
            lit *= mix(0.08, 1.0, smoothstep(mR * 0.85, mR * 1.25, off));
        }
        // Thin bright haze at the limb on the lit side, and a ring of light when backlit.
        float rim = pow(1.0 - z, 3.0);
        lit += mix(zone, vec3(0.8, 0.9, 1.0), 0.5) * rim * 0.25 * smoothstep(-0.2, 0.3, mu);
        lit += vec3(1.0, 0.95, 0.85) * pow(1.0 - z, 6.0) * smoothstep(0.2, -0.5, L.z) * 0.6 * smoothstep(-0.3, 0.2, dot(normalize(vec3(d, 0.0)), L));
        float cov = smoothstep(1.0 + px, 1.0 - px, r);
        planetL = vec4(lit * cov, cov);
        zPlanet = z;
    }

    if (ringKind >= 0 && rho < 2.45 * ringSc) {
        float op = giantRings(rho, fw, ringSc, seed, ringKind);
        if (op > 0.001) {
            float x = rho / ringSc;
            vec3 rc = ringKind == 1 ? vec3(0.4, 0.42, 0.45)
                    : mix(vec3(0.6, 0.55, 0.5), mix(zone, vec3(0.9, 0.82, 0.68), 0.6), smoothstep(1.45, 1.6, x));
            // Lit face vs unlit face: from the lit side the ring reflects; from the dark side light
            // only filters through, so thin rings glow and the dense ones go dark.
            float lp = dot(L, P);
            bool sameSide = lp * P.z > 0.0;
            float sunAmt = sqrt(abs(lp));
            vec3 rlit = sameSide ? rc * (0.15 + 1.1 * sunAmt) : rc * 3.0 * (1.0 - op) * sunAmt * 0.6 + rc * 0.02;
            // Planet's shadow on the rings.
            // Planet's shadow on the rings: a soft-edged shadow (the sun isn't a point, and the
            // planet's hazy upper atmosphere blurs the edge), with a little light from the planet's
            // day side still reaching in.
            float tc = -dot(X, L);
            if (tc > 0.0) {
                float cd = length(X + L * tc);
                float inShadow = 1.0 - smoothstep(0.96, 1.05, cd);
                float shine = 0.04 * clamp(0.5 + 0.5 * dot(normalize(-X), L), 0.0, 1.0) + 0.012;
                rlit = mix(rlit, rc * shine, inShadow);
            }
            // Spokes drifting around the B ring.
            float az = atan(dot(X, F), dot(X, Q));
            float spoke = smoothstep(0.6, 0.85, noise(vec2(az * 5.0 + lt * 0.03, x * 3.0 + seed)));
            rlit *= 1.0 - 0.25 * spoke * smoothstep(1.55, 1.7, x) * smoothstep(1.95, 1.8, x) * float(ringKind == 0);
            ringL = vec4(rlit * op, op);
        }
    }

    vec2 md = (d - M.xy) / mR;
    float mrr = length(md);
    if (mrr < 1.0 + px / mR) {
        float mz = sqrt(max(1.0 - mrr * mrr, 0.0));
        vec3 mn = vec3(md, mz);
        float crater = 0.6 + 0.4 * fbm(md * 3.0 + seed);
        vec3 mcol = vec3(0.75, 0.72, 0.68) * crater * (0.02 + 1.1 * max(dot(mn, L), 0.0));
        // In the planet's shadow?
        float tc = -dot(M, L);
        if (tc > 0.0) {
            mcol *= mix(0.03, 1.0, smoothstep(0.95, 1.05, length(M + L * tc)));
        }
        float mcov = smoothstep(1.0 + px / mR, 1.0 - px / mR, mrr);
        moonL = vec4(mcol * mcov, mcov);
    }

    // Composite near to far: larger z is closer to us.
    float zMoon = M.z + mR * 0.0;
    vec4 a = planetL; float za = zPlanet;
    vec4 b = ringL;   float zb = zRing;
    vec4 c3 = moonL;  float zc = zMoon;
    if (zb > za) { vec4 tv = a; a = b; b = tv; float tz = za; za = zb; zb = tz; }
    if (zc > zb) { vec4 tv = b; b = c3; c3 = tv; float tz = zb; zb = zc; zc = tz; }
    if (zb > za) { vec4 tv = a; a = b; b = tv; float tz = za; za = zb; zb = tz; }
    return over(a, over(b, c3));
}

vec4 giantPlanet(vec2 uv, float seed, float slot, float t, float fade) {
    float lt = eventTime(t);
    vec2 ext = halfExtent();
    float R = mix(0.26, 0.62, hash12(vec2(slot, seed + 517.0)));
    vec2 center = (hash22(vec2(slot * 5.1, seed + 519.0)) - 0.5) * 2.0 * ext * mix(0.2, 0.85, smoothstep(0.3, 0.62, R));
    center += (hash22(vec2(slot, seed + 521.0)) - 0.5) * 0.0002 * eventDrift(lt);
    // Sun: usually behind us and off to one side, so the planet's shadow falls back across the
    // far rings like the classic views; now and then from behind for a dramatic crescent.
    float sa = hash12(vec2(slot, seed + 529.0)) * 6.2831;
    float sz = hash12(vec2(slot, seed + 531.0));
    vec3 L = normalize(vec3(cos(sa), sin(sa) * 0.7, sz < 0.12 ? mix(-0.4, -0.1, sz / 0.12) : mix(0.35, 1.3, (sz - 0.12) / 0.88)));
    vec3 tint;
    return giantBody(uv, center, R, L, seed, slot, lt, tint) * fade;
}
