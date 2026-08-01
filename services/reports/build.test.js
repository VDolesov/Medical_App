const test = require('node:test');
const assert = require('node:assert');

const { buildReport, collectPatients, normalizeAge } = require('./build');

const norms = {
    'ТТГ': { id: 3, min_value: 0.4, max_value: 4.0, unit: 'мЕд/л' },
    'РЭА': { id: 8, min_value: 0.0, max_value: 5.0, unit: 'нг/мл' },
};

test('отклонения выше и ниже нормы попадают в отчёт', () => {
    const { report } = buildReport([{ 'Код пациента': '001', 'Возраст': 40, 'ТТГ': 9, 'РЭА': 0 }], norms);
    assert.strictEqual(report.length, 1);
    assert.strictEqual(report[0].outOfNorms.length, 1);
    assert.deepStrictEqual(report[0].outOfNorms[0], {
        analysis: 'ТТГ',
        value: 9,
        min: 0.4,
        max: 4.0,
        unit: 'мЕд/л',
        status: 'выше нормы',
    });
});

test('значение ниже нормы помечается отдельно', () => {
    const { report } = buildReport([{ 'Код пациента': '002', 'Возраст': 30, 'ТТГ': 0.1 }], norms);
    assert.strictEqual(report[0].outOfNorms[0].status, 'ниже нормы');
});

test('без отклонений подставляется заглушка', () => {
    const { report } = buildReport([{ 'Код пациента': '003', 'Возраст': 55, 'ТТГ': 2 }], norms);
    assert.deepStrictEqual(report[0].outOfNorms, ['Все значения в норме']);
});

test('строки без кода или возраста пропускаются', () => {
    const { report } = buildReport([
        { 'Код пациента': '', 'Возраст': 40, 'ТТГ': 9 },
        { 'Код пациента': '004', 'ТТГ': 9 },
        { 'Возраст': 20, 'ТТГ': 9 },
    ], norms);
    assert.strictEqual(report.length, 0);
});

test('неизвестные колонки и нечисловые значения игнорируются', () => {
    const { report, results } = buildReport(
        [{ 'Код пациента': '005', 'Возраст': 40, 'Рост': 180, 'ТТГ': 'нет данных' }],
        norms
    );
    assert.deepStrictEqual(report[0].outOfNorms, ['Все значения в норме']);
    assert.strictEqual(results.length, 0);
});

test('в результаты попадают все числовые значения, включая нормальные', () => {
    const { results } = buildReport([{ 'Код пациента': '006', 'Возраст': 40, 'ТТГ': 2, 'РЭА': 9 }], norms);
    assert.strictEqual(results.length, 2);
    assert.deepStrictEqual(results[0], { code: '006', normId: 3, value: 2 });
    assert.deepStrictEqual(results[1], { code: '006', normId: 8, value: 9 });
});

test('порядок пациентов сохраняется — на нём держится аналитика', () => {
    const { report } = buildReport([
        { 'Код пациента': 'A', 'Возраст': 1, 'ТТГ': 2 },
        { 'Код пациента': 'B', 'Возраст': 2, 'ТТГ': 2 },
        { 'Код пациента': 'C', 'Возраст': 3, 'ТТГ': 2 },
    ], norms);
    assert.deepStrictEqual(report.map(r => r.code), ['A', 'B', 'C']);
});

test('текстовый возраст превращается в null, а не роняет вставку', () => {
    assert.strictEqual(normalizeAge('тридцать'), null);
    assert.strictEqual(normalizeAge('н/д'), null);
    assert.strictEqual(normalizeAge(40), 40);
    assert.strictEqual(normalizeAge('40'), 40);
    assert.strictEqual(normalizeAge(40.7), 40);

    const patients = collectPatients([{ 'Код пациента': 'C001', 'Возраст': 'тридцать', 'ТТГ': 2 }]);
    assert.deepStrictEqual(patients, [{ code: 'C001', age: null }]);
});

test('пациент с текстовым возрастом всё равно попадает в отчёт', () => {
    const { report } = buildReport([{ 'Код пациента': 'C001', 'Возраст': 'тридцать', 'ТТГ': 9 }], norms);
    assert.strictEqual(report.length, 1);
    assert.strictEqual(report[0].age, 'тридцать');
    assert.strictEqual(report[0].outOfNorms[0].status, 'выше нормы');
});

test('файл без колонок кода и возраста даёт пустой отчёт', () => {
    const { report } = buildReport([{ 'ТТГ': 6.1, 'РЭА': 7 }], norms);
    assert.strictEqual(report.length, 0);
});

test('дубль строки не плодит пациентов, но остаётся в отчёте', () => {
    const rows = [
        { 'Код пациента': 'D001', 'Возраст': 38, 'ТТГ': 2 },
        { 'Код пациента': 'D001', 'Возраст': 38, 'ТТГ': 2 },
    ];
    assert.strictEqual(buildReport(rows, norms).report.length, 2);
    assert.strictEqual(collectPatients(rows).length, 1);
});

test('список пациентов схлопывает повторяющиеся коды', () => {
    const patients = collectPatients([
        { 'Код пациента': '007', 'Возраст': 40 },
        { 'Код пациента': '007', 'Возраст': 41 },
        { 'Код пациента': 8, 'Возраст': 50 },
    ]);
    assert.deepStrictEqual(patients, [{ code: '007', age: 40 }, { code: '8', age: 50 }]);
});
