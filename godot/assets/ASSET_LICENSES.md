# Third-party asset licenses

These assets are included under the Creative Commons CC0 1.0 Universal
dedication. Poly Haven states that its asset library is CC0; attribution is not
required. Credits are listed here for provenance.

License: <https://creativecommons.org/publicdomain/zero/1.0/>
Poly Haven license information: <https://polyhaven.com/license>

| Asset | Type | Creator | Source |
| --- | --- | --- | --- |
| Asphalt Track | 1K diffuse, OpenGL normal, and roughness maps | Dimitrios Savva | <https://polyhaven.com/a/asphalt_track> |
| Aerial Grass Rock | 1K diffuse, OpenGL normal, and roughness maps | Rob Tuytel | <https://polyhaven.com/a/aerial_grass_rock> |
| Shrub 03 | 1K glTF model and textures | Rico Cilliers | <https://polyhaven.com/a/shrub_03> |
| Shrub 04 | 1K glTF model and textures | Rico Cilliers | <https://polyhaven.com/a/shrub_04> |

The downloaded files were checked against the MD5 digests published by the
Poly Haven asset API. Only the listed files from these asset packages are
included.

## Project-authored environment geometry

The coconut and date palms beside the racing road are generated from original
procedural 3D geometry in `../scripts/race_palm_tree.gd`; they are not
third-party downloads. Their tapered trunks, individual fronds, and fruit
clusters are built as mesh surfaces at runtime. No external palm model or
unverified asset license is included.

## Vehicle

The race vehicle uses the Car Concept glTF sample, optimized by the Khronos
Group from a public-domain concept-car model by Unity Fan. The Khronos sample
asset is licensed CC BY 4.0, excluding Khronos and 3D Commerce logos:

- Creator: Eric Chadwick, 2024; Darmstadt Graphics Group GmbH.
- Source: <https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/CarConcept>
- Original public-domain model: <https://sketchfab.com/3d-models/free-concept-car-004-public-domain-cc0-4cba124633eb494eadc3bb0c4660ad7e>
- License: <https://creativecommons.org/licenses/by/4.0/>
- Required attribution: "Car Concept" by Eric Chadwick / Darmstadt Graphics Group GmbH, CC BY 4.0; based on the public-domain concept-car model by Unity Fan.

The game removes the steering emblem and license-plate nodes from the imported
scene so excluded logos and trademarks are not rendered. The GLB's scene
orientation and scale are adapted for the racing track.
