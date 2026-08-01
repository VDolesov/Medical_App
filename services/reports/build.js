const CODE_COLUMN = 'Код пациента';
const AGE_COLUMN = 'Возраст';

function buildReport(rows, norms) {
    const report = [];
    const results = [];

    for (const row of rows) {
        const code = row[CODE_COLUMN];
        const age = row[AGE_COLUMN];
        if (!code || String(code).trim() === '' || !age) {
            continue;
        }

        const patientReport = { code, age, outOfNorms: [] };

        for (const col of Object.keys(row)) {
            if (col === CODE_COLUMN || col === AGE_COLUMN) {
                continue;
            }
            const norm = norms[col];
            if (!norm) {
                continue;
            }
            const value = parseFloat(row[col]);
            if (Number.isNaN(value)) {
                continue;
            }

            results.push({ code: String(code).trim(), normId: norm.id, value });

            if (value < norm.min_value || value > norm.max_value) {
                patientReport.outOfNorms.push({
                    analysis: col,
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
            patients.set(key, { code: key, age });
        }
    }
    return [...patients.values()];
}

module.exports = { buildReport, collectPatients, CODE_COLUMN, AGE_COLUMN };
