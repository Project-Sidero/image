module sidero.colorimetry.colorspace.rgb.itu.rec709;
import sidero.colorimetry.colorspace.rgb.model;
import sidero.colorimetry.colorspace.defs;
import sidero.colorimetry.illuminants;
import sidero.base.text;
import sidero.base.errors;
import sidero.base.allocators;

///
static immutable CIEChromacityCoordinate[3] Rec709Chromacities = [
    CIEChromacityCoordinate(0.64, 0.33), CIEChromacityCoordinate(0.3, 0.6), CIEChromacityCoordinate(0.15, 0.06)
];
