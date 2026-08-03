const test = require('node:test');
const assert = require('node:assert');

const { buildReport, collectPatients, normalizeAge, normalizeMarkerName } = require('./build');

const norms = {
    'ТТГ': { id: 3, name: 'ТТГ', min_value: 0.4, max_value: 4.0, unit: 'мЕд/л' },
    'РЭА': { id: 8, name: 'РЭА', min_value: 0.0, max_value: 5.0, unit: 'нг/мл' },
};

const opNorms = {
    ...norms,
    'Т4 свободный': { id: 4, name: 'Т4 свободный', min_value: 9, max_value: 22, unit: 'пмоль/л' },
    'ТТГ после операции': { id: 11, name: 'ТТГ после операции', min_value: 0.4, max_value: 4.0, unit: 'мЕд/л' },
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

test('единицы измерения в заголовке не мешают распознать показатель', () => {
    assert.strictEqual(normalizeMarkerName('Кальцитонин (пг/мл)'), 'кальцитонин');
    assert.strictEqual(normalizeMarkerName('Т4 свободный, пмоль/л'), 'т4 свободный');
    assert.strictEqual(normalizeMarkerName('  РЭА  (нг/мл) '), 'рэа');

    const { report, results } = buildReport(
        [{ 'Код пациента': 'X1', 'Возраст': 50, 'РЭА (нг/мл)': 9, 'Т4 свободный, пмоль/л': 30 }],
        opNorms
    );
    assert.strictEqual(results.length, 2);
    assert.strictEqual(report[0].outOfNorms.length, 2);
    assert.deepStrictEqual(
        report[0].outOfNorms.map(o => o.analysis).sort(),
        ['РЭА', 'Т4 свободный']
    );
});

test('«после операции» не схлопывается с обычным показателем', () => {
    const { results } = buildReport(
        [{ 'Код пациента': 'X2', 'Возраст': 50, 'ТТГ (мЕд/л)': 9, 'ТТГ после операции': 2 }],
        opNorms
    );
    assert.deepStrictEqual(results.map(r => r.normId).sort((a, b) => a - b), [3, 11]);
});

test('две колонки на одну норму считаются один раз', () => {
    const { results } = buildReport(
        [{ 'Код пациента': 'X3', 'Возраст': 50, 'ТТГ': 9, 'ТТГ (мЕд/л)': 2 }],
        opNorms
    );
    assert.strictEqual(results.length, 1);
    assert.strictEqual(results[0].value, 9);
});

test('значение пересчитывается из единицы заголовка в единицу справочника', () => {
    const pth = { 'Паратгормон': { id: 6, name: 'Паратгормон', min_value: 15, max_value: 65, unit: 'пг/мл' } };

    const inRange = buildReport([{ 'Код пациента': 'U1', 'Возраст': 40, 'Паратгормон (пмоль/л)': 4 }], pth);
    assert.deepStrictEqual(inRange.report[0].outOfNorms, ['Все значения в норме']);
    assert.ok(Math.abs(inRange.results[0].value - 37.7) < 0.1);

    const above = buildReport([{ 'Код пациента': 'U2', 'Возраст': 40, 'Паратгормон (пмоль/л)': 9 }], pth);
    assert.strictEqual(above.report[0].outOfNorms[0].status, 'выше нормы');
});

test('колонка без единицы сравнивается со справочником напрямую', () => {
    const pth = { 'Паратгормон': { id: 6, name: 'Паратгормон', min_value: 15, max_value: 65, unit: 'пг/мл' } };
    const { report } = buildReport([{ 'Код пациента': 'U3', 'Возраст': 40, 'Паратгормон': 35 }], pth);
    assert.deepStrictEqual(report[0].outOfNorms, ['Все значения в норме']);
});

test('непересчитываемая единица пропускается, а не сравнивается как есть', () => {
    const tsh = { 'ТТГ': { id: 3, name: 'ТТГ', min_value: 0.4, max_value: 4, unit: 'мЕд/л' } };
    const { report, results } = buildReport([{ 'Код пациента': 'U4', 'Возраст': 40, 'ТТГ (пмоль/л)': 900 }], tsh);
    assert.strictEqual(results.length, 0);
    assert.strictEqual(report[0].measured, 0);
    assert.deepStrictEqual(report[0].outOfNorms, ['Все значения в норме']);
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
