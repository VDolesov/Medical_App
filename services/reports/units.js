const MASS_PER_VOLUME = {
    'г/л': 1,
    'мг/дл': 1e-2,
    'мг/л': 1e-3,
    'мкг/л': 1e-6,
    'нг/мл': 1e-6,
    'нг/дл': 1e-8,
    'пг/мл': 1e-9,
};

const MOLES_PER_VOLUME = {
    'ммоль/л': 1e-3,
    'мкмоль/л': 1e-6,
    'нмоль/л': 1e-9,
    'пмоль/л': 1e-12,
};

const SYNONYMS = {
    'ме/л': 'ед/л',
    'iu/l': 'ед/л',
    'u/l': 'ед/л',
    'мкг/мл': 'мг/л',
    'кме/л': 'ме/мл',
    'мме/л': 'мед/л',
    'мкме/мл': 'мед/л',
    'мкед/мл': 'мед/л',
};

const MOLAR_MASS = {
    'паратгормон': 9425,
    'кальцитонин': 3418,
    'т4 свободный': 776.87,
    'т4': 776.87,
    'кальций общий': 40.078,
};

function normalizeUnit(unit) {
    if (unit === undefined || unit === null) {
        return null;
    }
    const cleaned = String(unit)
        .replace(/\s+/g, '')
        .replace(/·/g, '/')
        .toLowerCase();
    if (!cleaned) {
        return null;
    }
    return SYNONYMS[cleaned] || cleaned;
}

function parseUnit(header) {
    if (header === undefined || header === null) {
        return null;
    }
    const text = String(header);
    const parens = text.match(/\(([^)]*)\)\s*$/);
    if (parens) {
        return normalizeUnit(parens[1]);
    }
    const comma = text.match(/,\s*([^,]+)$/);
    if (comma) {
        return normalizeUnit(comma[1]);
    }
    return null;
}

function analyteKey(name) {
    return String(name || '')
        .toLowerCase()
        .replace(/после операции/g, '')
        .replace(/\s+/g, ' ')
        .trim();
}

function convert(value, fromUnit, toUnit, analyteName) {
    const from = normalizeUnit(fromUnit);
    const to = normalizeUnit(toUnit);
    if (!from || !to || from === to) {
        return { ok: true, value };
    }

    if (MASS_PER_VOLUME[from] && MASS_PER_VOLUME[to]) {
        return { ok: true, value: value * (MASS_PER_VOLUME[from] / MASS_PER_VOLUME[to]) };
    }
    if (MOLES_PER_VOLUME[from] && MOLES_PER_VOLUME[to]) {
        return { ok: true, value: value * (MOLES_PER_VOLUME[from] / MOLES_PER_VOLUME[to]) };
    }

    const mass = MOLAR_MASS[analyteKey(analyteName)];
    if (mass) {
        if (MOLES_PER_VOLUME[from] && MASS_PER_VOLUME[to]) {
            return { ok: true, value: value * MOLES_PER_VOLUME[from] * mass / MASS_PER_VOLUME[to] };
        }
        if (MASS_PER_VOLUME[from] && MOLES_PER_VOLUME[to]) {
            return { ok: true, value: value * MASS_PER_VOLUME[from] / mass / MOLES_PER_VOLUME[to] };
        }
    }

    return { ok: false, value: null };
}

module.exports = { parseUnit, normalizeUnit, convert, analyteKey };
