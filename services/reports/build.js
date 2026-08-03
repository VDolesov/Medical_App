const { parseUnit, convert } = require('./units');

const CODE_COLUMN = 'Код пациента';
const AGE_COLUMN = 'Возраст';

function normalizeMarkerName(name) {
    return String(name)
        .replace(/\([^)]*\)/g, ' ')
        .replace(/,[^,]*$/, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .toLowerCase();
}

function indexNorms(norms) {
    const index = new Map();
    for (const [name, norm] of Object.entries(norms)) {
        const key = normalizeMarkerName(norm.name || name);
        if (!index.has(key)) {
            index.set(key, norm);
        }
    }
    return index;
}

function buildReport(rows, norms) {
    const report = [];
    const results = [];
    const index = indexNorms(norms);

    for (const row of rows) {
        const code = row[CODE_COLUMN];
        const age = row[AGE_COLUMN];
        if (!code || String(code).trim() === '' || !age) {
            continue;
        }

        const patientReport = { code, age, measured: 0, outOfNorms: [] };
        const seen = new Set();

        for (const col of Object.keys(row)) {
            if (col === CODE_COLUMN || col === AGE_COLUMN) {
                continue;
            }
            const norm = norms[col] || index.get(normalizeMarkerName(col));
            if (!norm || seen.has(norm.id)) {
                continue;
            }
            const raw = parseFloat(row[col]);
            if (Number.isNaN(raw)) {
                continue;
            }

            const converted = convert(raw, parseUnit(col), norm.unit, norm.name || col);
            if (!converted.ok) {
                continue;
            }
            const value = Math.round(converted.value * 1e6) / 1e6;

            seen.add(norm.id);
            patientReport.measured++;
            results.push({ code: String(code).trim(), normId: norm.id, value });

            if (value < norm.min_value || value > norm.max_value) {
                patientReport.outOfNorms.push({
                    analysis: norm.name || col,
                    value,
                    min: norm.min_value,
                    max: norm.max_value,
                    unit: norm.unit,
                    status: value < norm.min_value ? 'ниже нормы' : 'выше нормы',
                });
            }
        }

        if (patientReport.outOfNorms.length === 0) {
            patientReport.outOfNorms = ['Все значения в норме'];
        }
        report.push(patientReport);
    }

    return { report, results };
}

function normalizeAge(age) {
    const parsed = parseInt(age, 10);
    return Number.isFinite(parsed) ? parsed : null;
}

function collectPatients(rows) {
    const patients = new Map();
    for (const row of rows) {
        const code = row[CODE_COLUMN];
        const age = row[AGE_COLUMN];
        if (!code || String(code).trim() === '' || !age) {
            continue;
        }
        const key = String(code).trim();
        if (!patients.has(key)) {
            patients.set(key, { code: key, age: normalizeAge(age) });
        }
    }
    return [...patients.values()];
}

module.exports = { buildReport, collectPatients, normalizeAge, normalizeMarkerName, CODE_COLUMN, AGE_COLUMN };
