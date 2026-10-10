# AudioFX Wallpaper Glow

**A music-reactive wallpaper glow for Quickshell, because a static desktop apparently wasn't enough.**

AudioFX Wallpaper Glow analyses a wallpaper for bright, high-contrast details, builds glow masks, then uses CAVA's 16-band audio data to animate the glow through a Qt fragment shader. It is a small desktop visual experiment: part image processing, part signal analysis, part GPU rendering, and part answer to a question nobody asked.

This is a standalone adaptation inspired by the glow pipeline in `satoshoe-dev/dms-audiofx`. It does **not** require DankMaterialShell.

## The Asylum verdict

- **Does it work?** It is a real Quickshell component with a Python mask generator and a compiled Qt shader. It still needs to be tested on your specific Quickshell/Qt/CAVA setup. Graphics stacks enjoy having opinions.
- **Is it useful?** It makes a wallpaper react to music. Humanity's backlog of problems remains unaffected.
- **What does it teach?** Image segmentation, local contrast, multi-resolution blur, cache design, audio feature smoothing, shader uniforms, alpha blending, and the practical art of debugging a graphics pipeline.

## What it does

1. Loads the configured wallpaper.
2. Uses Pillow and NumPy to find colourful or bright details against their local surroundings.
3. Generates a core mask, a blurred halo, a low-resolution information texture, and a per-pixel colour texture.
4. Runs CAVA in raw 16-band mode.
5. Smooths the incoming bands and estimates bass transients.
6. Feeds the masks and audio features to a Qt ShaderEffect to render an animated glow.

The processing path is roughly:

```text
Wallpaper
   |
   v
RGB / HSV + local contrast
   |
   v
Candidate pixels -> core mask -> blurred halo
   |                            |
   +---- colour + phase data ---+
                 |
                 v
          Qt fragment shader <---- CAVA 16-band audio
                 |
                 v
        Music-reactive wallpaper glow
```

## Requirements

- Linux with [Quickshell](https://quickshell.org/) and Qt 6 ShaderEffect support
- Python 3
- Python packages: `numpy`, `Pillow`
- `cava`
- A compatible compiled shader at `shaders/glow.frag.qsb`

On Arch Linux, the relevant packages are commonly available as:

```bash
sudo pacman -S python-numpy python-pillow cava qt6-shadertools
```

Install Quickshell using the method appropriate for your distribution. 
Package names and Qt versions can differ, because consistency would apparently be too much to ask.

## Setup

1. Copy this project directory somewhere permanent.
2. Edit `Config.qml` and set `wallpaper` to the absolute path of the image you want to use.
3. Adjust `threshold`, `strength`, `bloom`, `sensitivity`, and `fps` as needed.
4. Load `shell.qml` using your Quickshell setup.

Example launch:

```bash
quickshell -p /path/to/dev-asylum-audiofx-wallpaper-glow/shell.qml
```

Check your installed Quickshell version's command-line options if `-p` differs in your package.

### Tuning

| Setting       | Effect                                              | Starting point |
|---------------|-----------------------------------------------------|---------------:|
| `threshold`   | Higher values select fewer, more pronounced details |           `30` |
| `strength`    | Core glow intensity                                 |          `3.7` |
| `bloom`       | Halo intensity                                      |          `2.5` |
| `sensitivity` | CAVA input sensitivity                              |          `100` |
| `fps`         | CAVA analysis frame rate                            |           `30` |

If the wallpaper turns into a radioactive soup, lower `strength` or `bloom`. 
If faint stars and nebula detail vanish, try lowering `threshold`. 
Change one variable at a time, or debugging becomes astrology with extra steps.

## Test the mask generator independently

This checks the Python/image-processing stage without starting Quickshell or CAVA:

```bash
python audiofx-glow.py /path/to/wallpaper.jpg --threshold 30
```

The script prints a JSON object containing the generated texture paths and a representative colour. 
Generated data is cached under `~/.cache/audiofx-wallpaper-glow/`.

Check the JSON and inspect `core.png`, `info.png`, and `colors.png` if the visual result is wrong. 
If this stage fails, the shader is innocent until proven otherwise.

## What can go wrong

- **No glow:** confirm the wallpaper path, generated mask JSON, and image texture loading.
- **Glow but no audio response:** run `cava` separately and verify its raw output and audio source.
- **Shader fails to load:** check Qt/Quickshell compatibility and whether `shaders/glow.frag.qsb` matches the GLSL source. Recompile it with the `qsb` tool supplied by Qt Shader Tools if needed.
- **Everything is too bright:** reduce `strength` and `bloom`. Inspect alpha blending and mask density.
- **High CPU usage:** inspect image dimensions, cache hits, CAVA frame rate, and whether the mask generator is being launched repeatedly.

## Engineering notes

The implementation is a prototype, not a production graphics framework. 
The cache key includes the image path, file size, modification timestamp, threshold, and generator version. 
The generator caps image width at 3840 pixels to avoid processing arbitrarily large wallpapers at full resolution.

The shader source is included for inspection. 
The `.qsb` file is a Qt Shader Tools binary and may need rebuilding if your Qt environment is incompatible. 
The original backup binary has been omitted because unexplained backups are not a release strategy.

See [docs/engineering-notes.md](docs/engineering-notes.md) for the design choices, limitations, and test checklist.

## Security and privacy

The project processes the wallpaper image you configure and reads audio-analysis data from CAVA. 
It does not need network access or an account. 
Avoid pointing it at images you do not have permission to use, and remember that CAVA's audio capture configuration is 
part of your local system setup.

This is a desktop visual experiment, not a security-sensitive service. 
No claims of production readiness are being made. 
The README is not a substitute for testing, despite the tragic number of projects that behave as if it were.