const test = require('node:test');
const assert = require('node:assert');

const scoring = require('./scoring');

test('все значения в норме — нулевой балл', () => {
    const result = scoring.compute({ outOfNorms: ['Все значения в норме'] });
    assert.strictEqual(result.riskScore, 0);
    assert.strictEqual(result.riskLevel, 'LOW');
    assert.strictEqual(result.deviationCount, 0);
    assert.deepStrictEqual(result.topFactors, []);
});

test('индекс усредняет выраженность по всей измеренной панели', () => {
    const slice = { measured: 16, outOfNorms: [{ analysis: 'Глюкоза', value: 8.0, min: 3.9, max: 6.1 }] };
    const result = scoring.compute(slice);
    assert.strictEqual(result.riskScore, 3);
    assert.strictEqual(result.riskLevel, 'LOW');
    assert.strictEqual(result.deviationCount, 1);
    assert.strictEqual(result.measuredCount, 16);
    assert.deepStrictEqual(result.topFactors, ['Глюкоза']);
});

test('то же отклонение в короткой панели весит больше', () => {
    const dev = { analysis: 'Глюкоза', value: 8.0, min: 3.9, max: 6.1 };
    const wide = scoring.compute({ measured: 16, outOfNorms: [dev] }).riskScore;
    const narrow = scoring.compute({ measured: 2, outOfNorms: [dev] }).riskScore;
    assert.ok(narrow > wide, `${narrow} должно быть больше ${wide}`);
    assert.strictEqual(narrow, 23);
});

test('размер панели не создаёт искусственного потолка', () => {
    const outOfNorms = [];
    for (let i = 0; i < 6; i++) {
        outOfNorms.push({ analysis: `Показатель ${i}`, value: 3, min: 1, max: 2 });
    }
    const result = scoring.compute({ measured: 16, outOfNorms });
    assert.ok(result.riskScore < 100, 'шесть отклонений из шестнадцати не должны давать 100');
    assert.strictEqual(result.riskScore, 19);
});

test('вся панель запредельна — индекс близок к сотне', () => {
    const outOfNorms = [];
    for (let i = 0; i < 16; i++) {
        outOfNorms.push({ analysis: `Показатель ${i}`, value: 1000, min: 1, max: 2 });
    }
    const result = scoring.compute({ measured: 16, outOfNorms });
    assert.strictEqual(result.riskScore, 100);
    assert.strictEqual(result.riskLevel, 'HIGH');
});

test('число измеренных показателей берётся из отчёта, иначе из справочника', () => {
    const dev = [{ analysis: 'ТТГ', value: 9, min: 0.4, max: 4 }];
    assert.strictEqual(scoring.compute({ measured: 8, outOfNorms: dev }, 16).measuredCount, 8);
    assert.strictEqual(scoring.compute({ outOfNorms: dev }, 16).measuredCount, 16);
    assert.strictEqual(scoring.compute({ outOfNorms: dev }).measuredCount, 1);
});

test('измеренных не может быть меньше числа отклонений', () => {
    const outOfNorms = [
        { analysis: 'A', value: 9, min: 0, max: 1 },
        { analysis: 'B', value: 9, min: 0, max: 1 },
        { analysis: 'C', value: 9, min: 0, max: 1 },
    ];
    assert.strictEqual(scoring.compute({ measured: 1, outOfNorms }).measuredCount, 3);
});

test('нечисловые границы дают силу отклонения 0.5', () => {
    const result = scoring.compute({ measured: 1, outOfNorms: [{ analysis: 'ТТГ', value: 'нет данных', min: null, max: null }] });
    assert.strictEqual(result.riskScore, 33);
    assert.strictEqual(scoring.deviationStrength({ value: 'x', min: 1, max: 2 }), 0.5);
});

test('повторный показатель схлопывается по максимальной силе', () => {
    const result = scoring.compute({
        outOfNorms: [
            { analysis: 'Кальций общий', value: 2.7, min: 2.15, max: 2.6 },
            { analysis: 'Кальций общий', value: 5.0, min: 2.15, max: 2.6 },
        ],
    });
    assert.strictEqual(result.deviationCount, 2);
    assert.deepStrictEqual(Object.keys(result.markerStrengths), ['Кальций общий']);
    assert.ok(result.markerStrengths['Кальций общий'] > 5);
});

test('строки-заглушки не считаются отклонениями', () => {
    const result = scoring.compute({ outOfNorms: ['Все значения в норме', { analysis: 'РЭА', value: 9, min: 0, max: 5 }] });
    assert.strictEqual(result.deviationCount, 1);
});

test('пустой и битый срез не роняют расчёт', () => {
    assert.strictEqual(scoring.compute(null).riskScore, 0);
    assert.strictEqual(scoring.compute({}).riskScore, 0);
    assert.strictEqual(scoring.compute({ outOfNorms: 'мусор' }).riskScore, 0);
});

test('сравнение динамики', () => {
    assert.strictEqual(scoring.compareTrend(30, 50), scoring.TREND_IMPROVING);
    assert.strictEqual(scoring.compareTrend(60, 40), scoring.TREND_WORSENING);
    assert.strictEqual(scoring.compareTrend(45, 44), scoring.TREND_STABLE);
    assert.strictEqual(scoring.compareTrend(10, null), scoring.TREND_NONE);
});

test('объяснение содержит дисклеймер и факторы', () => {
    const score = scoring.compute({
        outOfNorms: [{ analysis: 'Кальцитонин', value: 40, min: 0, max: 10 }],
    });
    const text = scoring.buildExplanation(score, scoring.TREND_WORSENING, 20);
    assert.ok(text.includes('не ставит диагнозы'));
    assert.ok(text.includes('Кальцитонин'));
    assert.ok(text.includes('было 20'));
    assert.ok(text.includes('ухудшение'));
});

test('без предыдущего отчёта динамика в объяснение не попадает', () => {
    const score = scoring.compute({ outOfNorms: ['Все значения в норме'] });
    const text = scoring.buildExplanation(score, scoring.TREND_NONE, null);
    assert.ok(text.includes('в пределах нормы'));
    assert.ok(!text.includes('Динамика'));
});
