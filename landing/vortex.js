// ============================================
// GPU Vortex with exact glyph atlas
// WebGL-based animated background effect
// ============================================

class WebGLVortex {
  constructor(canvas) {
    this.canvas = canvas;
    this.time = 0;
    this.animationId = null;
    this.isVisible = true;
    this.vortexChars = "░▒▓█▓▒░";
    // Fixed cell dimensions to match original 2D vortex
    this.charWidth = 10;
    this.charHeight = 16;

    this.gl =
      canvas.getContext("webgl") ||
      canvas.getContext("experimental-webgl");
    if (!this.gl) {
      console.warn("WebGL not supported, vortex disabled");
      return;
    }

    this.init();
  }

  init() {
    const gl = this.gl;

    this.glyphAtlas = this.createGlyphAtlas();

    const vertexShaderSource = `
      attribute vec2 a_position;
      varying vec2 v_uv;
      void main() {
          v_uv = a_position * 0.5 + 0.5;
          gl_Position = vec4(a_position, 0.0, 1.0);
      }
    `;

    const fragmentShaderSource = `
      precision highp float;

      varying vec2 v_uv;
      uniform float u_time;
      uniform vec2 u_resolution;
      uniform float u_viewportHeight;
      uniform float u_charWidth;
      uniform float u_charHeight;
      uniform float u_heroCenterRow;
      uniform float u_heroCenterCol;
      uniform float u_glyphCount;
      uniform vec2 u_atlasSize;
      uniform sampler2D u_glyphAtlas;
      uniform float u_cols;
      uniform float u_rows;
      uniform vec2 u_logoCenter;

      void main() {
          // Resolution is in CSS pixels (DPR=1)
          vec2 cssPixelPos = vec2(v_uv.x, 1.0 - v_uv.y) * u_resolution;

          float colExact = cssPixelPos.x / u_charWidth;
          float rowExact = cssPixelPos.y / u_charHeight;

          vec2 cellFrac = vec2(fract(colExact), fract(rowExact));

          float cols = u_cols;
          float totalRows = u_rows;

          float col = min(floor(colExact), cols - 1.0);
          float row = min(floor(rowExact), totalRows - 1.0);

          // Calculate center in PIXEL space, then convert to grid
          // The logo is at 50% of viewport
          float centerPxX = u_resolution.x / 2.0;
          float centerPxY = u_viewportHeight / 2.0;

          // Convert to grid coordinates using hardcoded char dimensions
          // (uniforms may have precision issues)
          float charW = 10.0;
          float charH = 16.0;
          float centerX = centerPxX / charW;
          float heroCenterY = centerPxY / charH;

          float aspectRatio = 1.8;
          float dx = col - centerX;
          float dy = (row - heroCenterY) * aspectRatio;
          float dist = sqrt(dx * dx + dy * dy);
          float angle = atan(dy, dx);

          float spiralTightness;
          float rotationSpeed;
          float waveFreq;
          float radialWeight;
          float colorR;
          float colorG;
          float colorB;

          if (cssPixelPos.y < u_viewportHeight) {
              spiralTightness = 0.08;
              rotationSpeed = 0.4;
              waveFreq = 0.2;
              radialWeight = 0.3;
              colorR = 0.0;
              colorG = 60.0;
              colorB = 100.0;
          } else {
              float belowFold = cssPixelPos.y - u_viewportHeight;
              float remainingHeight = u_resolution.y - u_viewportHeight;
              float t = clamp(belowFold / remainingHeight, 0.0, 1.0);

              spiralTightness = mix(0.08, 0.05, t);
              rotationSpeed = mix(0.4, 0.3, t);
              waveFreq = mix(0.2, 0.28, t);
              radialWeight = mix(0.3, 0.45, t);
              colorR = mix(0.0, 20.0, t);
              colorG = mix(60.0, 50.0, t);
              colorB = mix(100.0, 130.0, t);
          }

          float spiralAngle = angle + dist * spiralTightness - u_time * rotationSpeed;
          float spiralValue = sin(spiralAngle * 2.0) * 0.5 + 0.5;
          float radialWave = sin(dist * waveFreq - u_time * 0.6) * 0.5 + 0.5;
          float intensity = spiralValue * (1.0 - radialWeight) + radialWave * radialWeight;

          float maxDist = max(centerX, totalRows / 2.0) * 1.2;
          float distFade = 1.0 - min(dist / maxDist, 1.0);
          float finalIntensity = intensity * (0.15 + distFade * 0.6);

          float normalizedDist = min(dist / maxDist, 1.0);
          float r = colorR;
          float g = colorG + finalIntensity * 80.0;
          float b = colorB + finalIntensity * 100.0;

          float colorShift = sin(u_time * 0.5 + dist * 0.05) * 15.0;
          g = clamp(g + colorShift, 30.0, 180.0);

          if (normalizedDist < 0.25) {
              float centerBoost = (0.25 - normalizedDist) / 0.25;
              r = r + centerBoost * 40.0;
              g = g + centerBoost * 30.0;
              b = b + centerBoost * 20.0;
          }

          float alpha = 0.15 + finalIntensity * 0.5 * (1.0 - normalizedDist * 0.7);

          float glyphIndex = floor(finalIntensity * (u_glyphCount - 1.0));
          glyphIndex = clamp(glyphIndex, 0.0, u_glyphCount - 1.0);

          vec2 atlasPixel = vec2(
              (glyphIndex + cellFrac.x) * u_charWidth,
              cellFrac.y * u_charHeight
          );
          vec2 atlasUV = atlasPixel / u_atlasSize;

          float glyphAlpha = texture2D(u_glyphAtlas, atlasUV).a;

          if (finalIntensity < 0.05) {
              glyphAlpha = 0.0;
          }

          float finalAlpha = glyphAlpha * alpha;

          vec3 fgColor = vec3(r / 255.0, g / 255.0, b / 255.0) * 0.7;
          vec3 bgColor = vec3(0.02, 0.02, 0.04);

          vec3 finalColor = mix(bgColor, fgColor, finalAlpha);

          vec2 heroPixelCenter = vec2(centerX * u_charWidth, heroCenterY * u_charHeight);
          float gradientDist = length(cssPixelPos - heroPixelCenter);
          float maxGradientDist = max(u_resolution.x, u_resolution.y);
          if (gradientDist < maxGradientDist * 0.3) {
              float gradientAlpha = (1.0 - gradientDist / (maxGradientDist * 0.3)) * 0.05;
              finalColor += vec3(0.0, 0.83, 1.0) * gradientAlpha;
          }

          gl_FragColor = vec4(finalColor, 1.0);
      }
    `;

    const vertexShader = this.compileShader(
      gl.VERTEX_SHADER,
      vertexShaderSource,
    );
    const fragmentShader = this.compileShader(
      gl.FRAGMENT_SHADER,
      fragmentShaderSource,
    );

    this.program = gl.createProgram();
    gl.attachShader(this.program, vertexShader);
    gl.attachShader(this.program, fragmentShader);
    gl.linkProgram(this.program);

    if (!gl.getProgramParameter(this.program, gl.LINK_STATUS)) {
      console.error(
        "Program link failed:",
        gl.getProgramInfoLog(this.program),
      );
      return;
    }

    this.positionLocation = gl.getAttribLocation(
      this.program,
      "a_position",
    );
    this.timeLocation = gl.getUniformLocation(this.program, "u_time");
    this.resolutionLocation = gl.getUniformLocation(
      this.program,
      "u_resolution",
    );
    this.viewportHeightLocation = gl.getUniformLocation(
      this.program,
      "u_viewportHeight",
    );
    this.charWidthLocation = gl.getUniformLocation(
      this.program,
      "u_charWidth",
    );
    this.charHeightLocation = gl.getUniformLocation(
      this.program,
      "u_charHeight",
    );
    this.heroCenterRowLocation = gl.getUniformLocation(
      this.program,
      "u_heroCenterRow",
    );
    this.heroCenterColLocation = gl.getUniformLocation(
      this.program,
      "u_heroCenterCol",
    );
    this.colsLocation = gl.getUniformLocation(this.program, "u_cols");
    this.rowsLocation = gl.getUniformLocation(this.program, "u_rows");
    this.logoCenterLocation = gl.getUniformLocation(
      this.program,
      "u_logoCenter",
    );
    this.glyphCountLocation = gl.getUniformLocation(
      this.program,
      "u_glyphCount",
    );
    this.atlasSizeLocation = gl.getUniformLocation(
      this.program,
      "u_atlasSize",
    );
    this.glyphAtlasLocation = gl.getUniformLocation(
      this.program,
      "u_glyphAtlas",
    );

    this.positionBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, this.positionBuffer);
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]),
      gl.STATIC_DRAW,
    );

    this.glyphTexture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, this.glyphTexture);
    gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      this.glyphAtlas,
    );
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    this.resizePending = false;
    this.resize();
    const requestResize = () => {
      if (this.resizePending) return;
      this.resizePending = true;
      requestAnimationFrame(() => {
        this.resizePending = false;
        this.resize();
      });
    };
    window.addEventListener("resize", requestResize);
    window.addEventListener("orientationchange", requestResize);

    document.addEventListener("visibilitychange", () => {
      this.isVisible = !document.hidden;
      if (this.isVisible && !this.animationId) {
        this.animate();
      }
    });

    this.isVisible = true;
  }

  createGlyphAtlas() {
    const atlas = document.createElement("canvas");
    atlas.width = Math.ceil(this.vortexChars.length * this.charWidth);
    atlas.height = Math.ceil(this.charHeight);
    const ctx = atlas.getContext("2d");
    ctx.clearRect(0, 0, atlas.width, atlas.height);
    ctx.fillStyle = "#ffffff";
    ctx.font = `${this.charHeight - 2}px "JetBrains Mono", monospace`;
    ctx.textBaseline = "top";
    for (let i = 0; i < this.vortexChars.length; i++) {
      ctx.fillText(this.vortexChars[i], i * this.charWidth, 0);
    }
    return atlas;
  }

  compileShader(type, source) {
    const gl = this.gl;
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);

    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      console.error(
        "Shader compile failed:",
        gl.getShaderInfoLog(shader),
      );
      gl.deleteShader(shader);
      return null;
    }

    return shader;
  }

  resize() {
    // Canvas sized to full document (width x full page height)
    // Vortex center stays anchored on logo in hero section
    const width = window.innerWidth;
    const docEl = document.documentElement;
    const docHeight = Math.max(
      docEl.scrollHeight,
      docEl.offsetHeight,
      docEl.clientHeight
    );
    const height = docHeight;
    const viewportHeight = window.innerHeight;

    // Only resize canvas if dimensions actually changed
    // This prevents flicker from unnecessary canvas clears
    const needsResize = this.canvas.width !== width || this.canvas.height !== height;

    if (needsResize) {
      // Use DPR=1 to avoid coordinate space mismatches between
      // CSS pixels (getBoundingClientRect) and canvas pixels
      this.canvas.width = width;
      this.canvas.height = height;
      this.canvas.style.width = width + "px";
      this.canvas.style.height = height + "px";
      this.canvas.style.display = "block";
      this.canvas.style.margin = "0";
      this.gl.viewport(0, 0, width, height);
    }

    this.width = width;
    this.height = height;
    this.viewportHeight = viewportHeight;

    // Render immediately after resize to prevent black flash
    if (needsResize && this.program) {
      this.render();
    }
  }

  getCenter() {
    // Get actual logo position via getBoundingClientRect
    // Convert to document coordinates by adding scroll offset
    const logo = document.querySelector(".vide-logo");
    if (logo) {
      const logoRect = logo.getBoundingClientRect();
      const scrollX = window.scrollX || window.pageXOffset || 0;
      const scrollY = window.scrollY || window.pageYOffset || 0;
      // Convert viewport-relative to document-relative coordinates
      const centerX = logoRect.left + logoRect.width / 2 + scrollX;
      const centerY = logoRect.top + logoRect.height / 2 + scrollY;
      return {
        centerCol: centerX / this.charWidth,
        centerRow: centerY / this.charHeight,
        pxX: centerX,
        pxY: centerY,
      };
    }

    // Fallback: use canvas/viewport center
    return {
      centerCol: (this.width / 2) / this.charWidth,
      centerRow: (this.viewportHeight / 2) / this.charHeight,
      pxX: this.width / 2,
      pxY: this.viewportHeight / 2,
    };
  }

  render() {
    const gl = this.gl;

    gl.useProgram(this.program);

    gl.uniform1f(this.timeLocation, this.time);
    gl.uniform2f(this.resolutionLocation, this.width, this.height);
    gl.uniform1f(this.viewportHeightLocation, this.viewportHeight);
    const center = this.getCenter();
    const cols = Math.ceil(this.width / this.charWidth);
    const rows = Math.ceil(this.height / this.charHeight);
    gl.uniform1f(this.charWidthLocation, this.charWidth);
    gl.uniform1f(this.charHeightLocation, this.charHeight);
    gl.uniform1f(this.heroCenterRowLocation, center.centerRow);
    gl.uniform1f(this.heroCenterColLocation, center.centerCol);
    gl.uniform1f(this.colsLocation, cols);
    gl.uniform1f(this.rowsLocation, rows);
    gl.uniform2f(
      this.logoCenterLocation,
      center.logoPxX !== undefined ? center.logoPxX : -1.0,
      center.logoPxY !== undefined ? center.logoPxY : -1.0,
    );
    gl.uniform1f(this.glyphCountLocation, this.vortexChars.length);
    gl.uniform2f(
      this.atlasSizeLocation,
      this.glyphAtlas.width,
      this.glyphAtlas.height,
    );

    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.glyphTexture);
    gl.uniform1i(this.glyphAtlasLocation, 0);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.positionBuffer);
    gl.enableVertexAttribArray(this.positionLocation);
    gl.vertexAttribPointer(
      this.positionLocation,
      2,
      gl.FLOAT,
      false,
      0,
      0,
    );

    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }

  animate() {
    if (!this.isVisible) {
      this.animationId = null;
      return;
    }

    this.time += 0.012;
    this.render();
    this.animationId = requestAnimationFrame(() => this.animate());
  }

  start() {
    this.animate();
  }
}

// ============================================
// Initialize vortex on DOM ready
// ============================================

document.addEventListener("DOMContentLoaded", () => {
  const prefersReducedMotion = window.matchMedia(
    "(prefers-reduced-motion: reduce)",
  ).matches;

  if (!prefersReducedMotion) {
    const startVortex = () => {
      const vortexCanvas = document.getElementById("vortex-canvas");
      if (vortexCanvas) {
        const vortex = new WebGLVortex(vortexCanvas);
        vortex.start();
      }
    };

    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(startVortex);
    } else {
      startVortex();
    }
  }
});
