/**
It is recommended to use D65 2 degrees observer where possible,
 when not possible D50, D55 or D75 is recommended.
 */
module sidero.colorimetry.illuminants;
public import sidero.colorimetry.colorspace.defs : Illuminant;

/**
https://en.wikipedia.org/wiki/Standard_illuminant

Defined as CIE xyY.
*/
enum Illuminants : Illuminant {
    ///
    A_2Degrees = Illuminant(0.44757, 0.40745, 1),
    ///
    B_2Degrees = Illuminant(0.34842, 0.35161, 1),
    ///
    C_2Degrees = Illuminant(0.31006, 0.31616, 1),
    ///
    D50_2Degrees = Illuminant(0.34567, 0.3585, 1),
    ///
    D55_2Degrees = Illuminant(0.33242, 0.34743, 1),
    ///
    D65_2Degrees = Illuminant(0.31271, 0.32902, 1),
    ///
    D75_2Degrees = Illuminant(0.29902, 0.31485, 1),
    ///
    D93_2Degrees = Illuminant(0.28315, 0.29711, 1),
    ///
    E_2Degrees = Illuminant(0.33333, 0.33333, 1),
    ///
    F1_2Degrees = Illuminant(0.3131, 0.33727, 1),
    ///
    F2_2Degrees = Illuminant(0.37208, 0.37529, 1),
    ///
    F3_2Degrees = Illuminant(0.4091, 0.3943, 1),
    ///
    F4_2Degrees = Illuminant(0.44018, 0.40329, 1),
    ///
    F5_2Degrees = Illuminant(0.31379, 0.34531, 1),
    ///
    F6_2Degrees = Illuminant(0.3779, 0.38835, 1),
    ///
    F7_2Degrees = Illuminant(0.31292, 0.32933, 1),
    ///
    F8_2Degrees = Illuminant(0.34588, 0.35875, 1),
    ///
    F9_2Degrees = Illuminant(0.37417, 0.37281, 1),
    ///
    F10_2Degrees = Illuminant(0.34609, 0.35986, 1),
    ///
    F11_2Degrees = Illuminant(0.38052, 0.37713, 1),
    ///
    F12_2Degrees = Illuminant(0.43695, 0.40441, 1),
    ///
    LEDB1_2Degrees = Illuminant(0.456, 0.4078, 1),
    ///
    LEDB2_2Degrees = Illuminant(0.4357, 0.4012, 1),
    ///
    LEDB3_2Degrees = Illuminant(0.3756, 0.3723, 1),
    ///
    LEDB4_2Degrees = Illuminant(0.3422, 0.3502, 1),
    ///
    LEDB5_2Degrees = Illuminant(0.3118, 0.3236, 1),
    ///
    LEDBH1_2Degrees = Illuminant(0.4474, 0.4066, 1),
    ///
    LEDRGB1_2Degrees = Illuminant(0.4557, 0.4211, 1),
    ///
    LEDV1_2Degrees = Illuminant(0.456, 0.4548, 1),
    ///
    LEDV2_2Degrees = Illuminant(0.3781, 0.3775, 1),

    ///
    A_10Degrees = Illuminant(0.45117, 0.40594, 0.14289),
    ///
    B_10Degrees = Illuminant(0.3498, 0.3527, 0.2975),
    ///
    C_10Degrees = Illuminant(0.31039, 0.31905, 0.37056),
    ///
    D50_10Degrees = Illuminant(0.34773, 0.35952, 0.29275),
    ///
    D55_10Degrees = Illuminant(0.33411, 0.34877, 0.31712),
    ///
    D65_10Degrees = Illuminant(0.31382, 0.331, 0.35518),
    ///
    D75_10Degrees = Illuminant(0.29968, 0.3174, 0.38292),
    ///
    D93_10Degrees = Illuminant(0.28327, 0.30043, 0.4163),
    ///
    E_10Degrees = Illuminant(0.33333, 0.33333, 0.33334),
    ///
    F1_10Degrees = Illuminant(0.31811, 0.33559, 0.3463),
    ///
    F2_10Degrees = Illuminant(0.37925, 0.36733, 0.25342),
    ///
    F3_10Degrees = Illuminant(0.41761, 0.38324, 0.19915),
    ///
    F4_10Degrees = Illuminant(0.4492, 0.39074, 0.16006),
    ///
    F5_10Degrees = Illuminant(0.31975, 0.34246, 0.33779),
    ///
    F6_10Degrees = Illuminant(0.3866, 0.37847, 0.23493),
    ///
    F7_10Degrees = Illuminant(0.31569, 0.3296, 0.35471),
    ///
    F8_10Degrees = Illuminant(0.34902, 0.35939, 0.29159),
    ///
    F9_10Degrees = Illuminant(0.37829, 0.37045, 0.25126),
    ///
    F10_10Degrees = Illuminant(0.3509, 0.35444, 0.29466),
    ///
    F11_10Degrees = Illuminant(0.38541, 0.37123, 0.24336),
    ///
    F12_10Degrees = Illuminant(0.44256, 0.39717, 0.16027),
}
