# Test plan

The archive does not include automated integration tests for Quickshell, CAVA, or the GPU shader. 
Treat the checklist below as required manual validation before claiming the project works on a given machine.

## Python generator

1. Generate masks for a valid RGB/JPEG or PNG wallpaper.
2. Confirm the command exits successfully and prints parseable JSON.
3. Confirm all reported texture paths exist and can be opened.
4. Repeat with the same file and threshold; confirm the cache is reused.
5. Try a missing file and thresholds below 0 or above 100; confirm a clear error.
6. Try a mostly dark image, a high-saturation image, and a low-colour image.

## Runtime integration

1. Confirm the Qt ShaderEffect loads the `.qsb` file.
2. Confirm all texture inputs reach `Image.Ready`.
3. Confirm CAVA is running with 16-band raw output.
4. Test both audio silence and active playback.
5. Watch for repeated mask-generator launches, errors, and excessive CPU/GPU usage.

Record actual outcomes in the release notes. 
A checklist is a plan, not evidence that the tests passed. 
This distinction has been responsible for a surprising amount of software.
