#version 460 core

#include <flutter/runtime_effect.glsl>

uniform float u_time;
uniform vec2 u_resolution;
uniform vec2 u_center;

out vec4 fragColor;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    // Grid cell dimensions (matching landing page)
    float charWidth = 10.0;
    float charHeight = 16.0;

    // Convert to grid coordinates
    float col = floor(fragCoord.x / charWidth);
    float row = floor(fragCoord.y / charHeight);

    // Center in grid coordinates
    float centerX = u_center.x / charWidth;
    float centerY = u_center.y / charHeight;

    float cols = ceil(u_resolution.x / charWidth);
    float totalRows = ceil(u_resolution.y / charHeight);

    // Distance and angle from center
    float aspectRatio = 1.8;
    float dx = col - centerX;
    float dy = (row - centerY) * aspectRatio;
    float dist = sqrt(dx * dx + dy * dy);
    float angle = atan(dy, dx);

    // Spiral pattern — exact landing page values
    float spiralTightness = 0.08;
    float rotationSpeed = 0.4;
    float waveFreq = 0.2;
    float radialWeight = 0.3;

    float spiralAngle = angle + dist * spiralTightness - u_time * rotationSpeed;
    float spiralValue = sin(spiralAngle * 2.0) * 0.5 + 0.5;
    float radialWave = sin(dist * waveFreq - u_time * 0.6) * 0.5 + 0.5;
    float intensity = spiralValue * (1.0 - radialWeight) + radialWave * radialWeight;

    // Distance fade
    float maxDist = max(centerX, totalRows / 2.0) * 1.2;
    float distFade = 1.0 - min(dist / maxDist, 1.0);
    float finalIntensity = intensity * (0.15 + distFade * 0.6);

    // Teal/cyan color palette
    float normalizedDist = min(dist / maxDist, 1.0);
    float r = 0.0;
    float g = 60.0 + finalIntensity * 80.0;
    float b = 100.0 + finalIntensity * 100.0;

    // Color shift on green channel
    float colorShift = sin(u_time * 0.5 + dist * 0.05) * 15.0;
    g = clamp(g + colorShift, 30.0, 180.0);

    // Center boost — warmer colors near center
    if (normalizedDist < 0.25) {
        float centerBoost = (0.25 - normalizedDist) / 0.25;
        r = r + centerBoost * 40.0;
        g = g + centerBoost * 30.0;
        b = b + centerBoost * 20.0;
    }

    // Alpha / visibility
    float alpha = 0.15 + finalIntensity * 0.5 * (1.0 - normalizedDist * 0.7);

    // Skip very low intensity cells
    if (finalIntensity < 0.05) {
        alpha = 0.0;
    }

    // Compose foreground with background
    vec3 fgColor = vec3(r / 255.0, g / 255.0, b / 255.0) * 0.7;
    vec3 bgColor = vec3(0.02, 0.02, 0.04);

    vec3 finalColor = mix(bgColor, fgColor, alpha);

    // Central glow — subtle teal radial gradient
    float gradientDist = length(fragCoord - u_center);
    float maxGradientDist = max(u_resolution.x, u_resolution.y);
    if (gradientDist < maxGradientDist * 0.3) {
        float gradientAlpha = (1.0 - gradientDist / (maxGradientDist * 0.3)) * 0.05;
        finalColor += vec3(0.0, 0.83, 1.0) * gradientAlpha;
    }

    fragColor = vec4(finalColor, 1.0);
}
