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

test('одно отклонение считается по формуле 18*n + 52*avg', () => {
    const result = scoring.compute({
        outOfNorms: [{ analysis: 'Глюкоза', value: 8.0, min: 3.9, max: 6.1 }],
    });
    assert.strictEqual(result.riskScore, 63);
    assert.strictEqual(result.riskLevel, 'MEDIUM');
    assert.strictEqual(result.deviationCount, 1);
    assert.deepStrictEqual(result.topFactors, ['Глюкоза']);
});

test('балл ограничен сотней', () => {
    const outOfNorms = [];
    for (let i = 0; i < 5; i++) {
        outOfNorms.push({ analysis: `Показатель ${i}`, value: 30, min: 1, max: 2 });
    }
    const result = scoring.compute({ outOfNorms });
    assert.strictEqual(result.riskScore, 100);
    assert.strictEqual(result.riskLevel, 'HIGH');
    assert.strictEqual(result.topFactors.length, 5);
});

test('нечисловые границы дают силу отклонения 0.5', () => {
    const result = scoring.compute({
        outOfNorms: [{ analysis: 'ТТГ', value: 'нет данных', min: null, max: null }],
    });
    assert.strictEqual(result.riskScore, 44);
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
