# Engineering notes

## Design

The generator combines colour saturation, brightness, and local contrast rather than treating every bright pixel as a glow source. 
A downsampled and blurred value image approximates the surrounding luminance. 
Candidate pixels are used to estimate density, then a softened core mask and Gaussian halo are produced.

The shader samples the core mask, halo information, and wallpaper colours. 
It maps the horizontal coordinate to one of 16 audio bands, adds a smoothed global level and a small time-varying flicker, 
then composites the resulting light using alpha blending.

## Why these choices?

- **Local contrast:** bright regions are more meaningful when they stand out from their surroundings.
- **Multi-resolution processing:** downsampling before blur reduces the cost of broad neighbourhood operations.
- **Separate core and halo textures:** sharp light sources and broad bloom need different falloff.
- **Audio smoothing:** attack and release rates are separated to avoid a jittery result.
- **A bounded image width:** limits memory use and processing time on unusually large source images.
- **A cache key:** ties generated textures to the input path, file metadata, threshold, and generator version.

## Known limitations

- The segmentation heuristics are image-dependent. A threshold that works on a starfield may be poor for a photograph or illustration.
- The cache uses file metadata rather than a content hash of the full image. Replacing a file while preserving its size 
and modification time can produce a stale hit.
- Audio behaviour depends on the host's CAVA configuration and audio source.
- Qt's `.qsb` binary is toolchain-sensitive. The included shader source is the inspectable reference. Rebuild the binary if it is incompatible.
- The current design is a desktop effect, not a general-purpose image-analysis library.

## Validation checklist

Run these checks on the target machine before calling a release tested:

- [ ] Run the generator on a normal wallpaper.
- [ ] Run it on a very dark image and a highly saturated image.
- [ ] Confirm a second run reuses the cache.
- [ ] Confirm a missing image produces a useful error.
- [ ] Inspect the generated masks at full size.
- [ ] Launch the Quickshell component and verify the shader compiles/loads.
- [ ] Confirm CAVA produces 16 values per frame.
- [ ] Test silence, speech, music, and abrupt bass transients.
- [ ] Test at the intended display resolution and monitor layout.
- [ ] Observe CPU/GPU use over a sustained session.
- [ ] Record Qt, Quickshell, CAVA, Python, NumPy, and Pillow versions in release notes.

## Failure reporting

When reporting a bug, include: 
* Distribution 
* Qt/Quickshell/CAVA versions 
* GPU/driver details
* display resolution
* relevant console output
* Whether the python generator works independently

Do not attach private wallpaper files unless you have checked that you are comfortable sharing them.
