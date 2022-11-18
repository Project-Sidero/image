/**
It is recommended to use D65 2 degrees observer where possible,
 when not possible D50, D55 or D75 is recommended.
 */
module sidero.colorimetry.illuminants;
public import sidero.colorimetry.colorspace.defs : CIEChromacityCoordinate;

/**
https://en.wikipedia.org/wiki/Standard_illuminant

Defined as CIE xyY.
*/
enum Illuminants : CIEChromacityCoordinate {
    ///
    A_2Degrees = CIEChromacityCoordinate(0.44757, 0.40745),
    ///
    B_2Degrees = CIEChromacityCoordinate(0.34842, 0.35161),
    ///
    C_2Degrees = CIEChromacityCoordinate(0.31006, 0.31616),
    ///
    D50_2Degrees = CIEChromacityCoordinate(0.34567, 0.3585),
    ///
    D55_2Degrees = CIEChromacityCoordinate(0.33242, 0.34743),
    ///
    D65_2Degrees = CIEChromacityCoordinate(0.31271, 0.32902),
    ///
    D75_2Degrees = CIEChromacityCoordinate(0.29902, 0.31485),
    ///
    D93_2Degrees = CIEChromacityCoordinate(0.28315, 0.29711),
    ///
    E_2Degrees = CIEChromacityCoordinate(0.33333, 0.33333),
    ///
    F1_2Degrees = CIEChromacityCoordinate(0.3131, 0.33727),
    ///
    F2_2Degrees = CIEChromacityCoordinate(0.37208, 0.37529),
    ///
    F3_2Degrees = CIEChromacityCoordinate(0.4091, 0.3943),
    ///
    F4_2Degrees = CIEChromacityCoordinate(0.44018, 0.40329),
    ///
    F5_2Degrees = CIEChromacityCoordinate(0.31379, 0.34531),
    ///
    F6_2Degrees = CIEChromacityCoordinate(0.3779, 0.38835),
    ///
    F7_2Degrees = CIEChromacityCoordinate(0.31292, 0.32933),
    ///
    F8_2Degrees = CIEChromacityCoordinate(0.34588, 0.35875),
    ///
    F9_2Degrees = CIEChromacityCoordinate(0.37417, 0.37281),
    ///
    F10_2Degrees = CIEChromacityCoordinate(0.34609, 0.35986),
    ///
    F11_2Degrees = CIEChromacityCoordinate(0.38052, 0.37713),
    ///
    F12_2Degrees = CIEChromacityCoordinate(0.43695, 0.40441),
    ///
    LEDB1_2Degrees = CIEChromacityCoordinate(0.456, 0.4078),
    ///
    LEDB2_2Degrees = CIEChromacityCoordinate(0.4357, 0.4012),
    ///
    LEDB3_2Degrees = CIEChromacityCoordinate(0.3756, 0.3723),
    ///
    LEDB4_2Degrees = CIEChromacityCoordinate(0.3422, 0.3502),
    ///
    LEDB5_2Degrees = CIEChromacityCoordinate(0.3118, 0.3236),
    ///
    LEDBH1_2Degrees = CIEChromacityCoordinate(0.4474, 0.4066),
    ///
    LEDRGB1_2Degrees = CIEChromacityCoordinate(0.4557, 0.4211),
    ///
    LEDV1_2Degrees = CIEChromacityCoordinate(0.456, 0.4548),
    ///
    LEDV2_2Degrees = CIEChromacityCoordinate(0.3781, 0.3775),

    ///
    A_10Degrees = CIEChromacityCoordinate(0.45117, 0.40594),
    ///
    B_10Degrees = CIEChromacityCoordinate(0.3498, 0.3527),
    ///
    C_10Degrees = CIEChromacityCoordinate(0.31039, 0.31905),
    ///
    D50_10Degrees = CIEChromacityCoordinate(0.34773, 0.35952),
    ///
    D55_10Degrees = CIEChromacityCoordinate(0.33411, 0.34877),
    ///
    D65_10Degrees = CIEChromacityCoordinate(0.31382, 0.331),
    ///
    D75_10Degrees = CIEChromacityCoordinate(0.29968, 0.3174),
    ///
    D93_10Degrees = CIEChromacityCoordinate(0.28327, 0.30043),
    ///
    E_10Degrees = CIEChromacityCoordinate(0.33333, 0.33333),
    ///
    F1_10Degrees = CIEChromacityCoordinate(0.31811, 0.33559),
    ///
    F2_10Degrees = CIEChromacityCoordinate(0.37925, 0.36733),
    ///
    F3_10Degrees = CIEChromacityCoordinate(0.41761, 0.38324),
    ///
    F4_10Degrees = CIEChromacityCoordinate(0.4492, 0.39074),
    ///
    F5_10Degrees = CIEChromacityCoordinate(0.31975, 0.34246),
    ///
    F6_10Degrees = CIEChromacityCoordinate(0.3866, 0.37847),
    ///
    F7_10Degrees = CIEChromacityCoordinate(0.31569, 0.3296),
    ///
    F8_10Degrees = CIEChromacityCoordinate(0.34902, 0.35939),
    ///
    F9_10Degrees = CIEChromacityCoordinate(0.37829, 0.37045),
    ///
    F10_10Degrees = CIEChromacityCoordinate(0.3509, 0.35444),
    ///
    F11_10Degrees = CIEChromacityCoordinate(0.38541, 0.37123),
    ///
    F12_10Degrees = CIEChromacityCoordinate(0.44256, 0.39717),
}
