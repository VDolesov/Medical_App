const test = require('node:test');
const assert = require('node:assert');

const { parseUnit, normalizeUnit, convert } = require('./units');

function close(actual, expected, eps = 1e-6) {
    assert.ok(Math.abs(actual - expected) < eps, `${actual} ≈ ${expected}`);
}

test('единица вычитается из заголовка колонки', () => {
    assert.strictEqual(parseUnit('Паратгормон (пмоль/л)'), 'пмоль/л');
    assert.strictEqual(parseUnit('Т4 свободный, пмоль/л'), 'пмоль/л');
    assert.strictEqual(parseUnit('Кальцитонин (пг/мл)'), 'пг/мл');
    assert.strictEqual(parseUnit('Щелочная фосфатаза'), null);
    assert.strictEqual(parseUnit('Кальций общий после операции'), null);
});

test('синонимы единиц сводятся к одной записи', () => {
    assert.strictEqual(normalizeUnit('МЕ/л'), 'ед/л');
    assert.strictEqual(normalizeUnit('U/L'), 'ед/л');
    assert.strictEqual(normalizeUnit('мкМЕ/мл'), 'мед/л');
    assert.strictEqual(normalizeUnit(' пг / мл '), 'пг/мл');
});

test('одинаковые единицы не пересчитываются', () => {
    assert.deepStrictEqual(convert(5, 'пг/мл', 'пг/мл', 'Кальцитонин'), { ok: true, value: 5 });
    assert.deepStrictEqual(convert(5, null, 'пг/мл', 'Кальцитонин'), { ok: true, value: 5 });
});

test('пересчёт внутри массовых единиц', () => {
    close(convert(1, 'мг/дл', 'мг/л', 'Кальций общий').value, 10);
    close(convert(1000, 'пг/мл', 'нг/мл', 'РЭА').value, 1);
});

test('пересчёт внутри молярных единиц', () => {
    close(convert(1000, 'пмоль/л', 'нмоль/л', 'Паратгормон').value, 1);
    close(convert(1, 'ммоль/л', 'мкмоль/л', 'Кальций общий').value, 1000);
});

test('паратгормон: пмоль/л в пг/мл через молярную массу', () => {
    close(convert(1, 'пмоль/л', 'пг/мл', 'Паратгормон').value, 9.425, 1e-3);
    close(convert(9.425, 'пг/мл', 'пмоль/л', 'Паратгормон').value, 1, 1e-3);
});

test('норма паратгормона 15–65 пг/мл это примерно 1.6–6.9 пмоль/л', () => {
    close(convert(15, 'пг/мл', 'пмоль/л', 'Паратгормон').value, 1.59, 0.01);
    close(convert(65, 'пг/мл', 'пмоль/л', 'Паратгормон').value, 6.90, 0.01);
});

test('послеоперационный показатель использует ту же молярную массу', () => {
    close(convert(1, 'пмоль/л', 'пг/мл', 'Паратгормон после операции').value, 9.425, 1e-3);
});

test('кальций: ммоль/л в мг/дл', () => {
    close(convert(1, 'ммоль/л', 'мг/дл', 'Кальций общий').value, 4.008, 1e-3);
    close(convert(2.15, 'ммоль/л', 'мг/дл', 'Кальций общий').value, 8.617, 1e-3);
});

test('неизвестный пересчёт честно возвращает отказ', () => {
    assert.strictEqual(convert(5, 'ед/л', 'пг/мл', 'Щелочная фосфатаза').ok, false);
    assert.strictEqual(convert(5, 'пмоль/л', 'пг/мл', 'ТТГ').ok, false);
});
