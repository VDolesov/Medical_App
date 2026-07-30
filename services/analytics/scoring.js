const TREND_NONE = 'NONE';
const TREND_IMPROVING = 'IMPROVING';
const TREND_WORSENING = 'WORSENING';
const TREND_STABLE = 'STABLE';

function extractDeviations(rowSlice) {
    if (!rowSlice) {
        return [];
    }
    const raw = rowSlice.outOfNorms;
    if (!Array.isArray(raw)) {
        return [];
    }
    return raw.filter(item => item !== null && typeof item === 'object' && !Array.isArray(item));
}

function deviationStrength(item) {
    const value = item.value;
    const min = item.min;
    const max = item.max;
    if (!Number.isFinite(value) || !Number.isFinite(min) || !Number.isFinite(max)) {
        return 0.5;
    }
    let range = max - min;
    if (range <= 1e-9) {
        range = 1.0;
    }
    if (value < min) {
        return (min - value) / range;
    }
    if (value > max) {
        return (value - max) / range;
    }
    return 0.0;
}

function compute(rowSlice) {
    const deviations = extractDeviations(rowSlice);
    if (deviations.length === 0) {
        return { riskScore: 0, riskLevel: 'LOW', deviationCount: 0, markerStrengths: {}, topFactors: [] };
    }

    const strengths = new Map();
    let sumCapped = 0;
    for (const item of deviations) {
        const name = item.analysis === undefined || item.analysis === null ? '?' : String(item.analysis);
        const strength = deviationStrength(item);
        const known = strengths.get(name);
        strengths.set(name, known === undefined ? strength : Math.max(known, strength));
        sumCapped += Math.min(1.0, strength);
    }

    const n = deviations.length;
    const avgCapped = sumCapped / n;
    const raw = Math.round(18.0 * n + 52.0 * avgCapped);
    const riskScore = Math.min(100, Math.max(0, raw));
    const riskLevel = riskScore <= 35 ? 'LOW' : (riskScore <= 70 ? 'MEDIUM' : 'HIGH');

    const topFactors = [...strengths.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(entry => entry[0]);

    return {
        riskScore,
        riskLevel,
        deviationCount: n,
        markerStrengths: Object.fromEntries(strengths),
        topFactors,
    };
}

function compareTrend(currentScore, previousScore) {
    if (previousScore === null || previousScore === undefined) {
        return TREND_NONE;
    }
    const delta = currentScore - previousScore;
    if (delta <= -8) {
        return TREND_IMPROVING;
    }
    if (delta >= 8) {
        return TREND_WORSENING;
    }
    return TREND_STABLE;
}

function levelRu(level) {
    switch (level) {
        case 'LOW':
            return 'минимальная выраженность отклонений';
        case 'MEDIUM':
            return 'умеренная выраженность отклонений';
        case 'HIGH':
            return 'выраженные отклонения';
        default:
            return level;
    }
}

function buildExplanation(score, trend, previousRiskScore) {
    let text = 'Оценка основана на количестве и силе отклонений показателей от референсных диапазонов в загруженном файле. ';
    text += 'Это не диагноз и не замена очной консультации врача.\n\n';

    if (score.deviationCount === 0) {
        text += 'Все учтённые показатели в пределах нормы для данного отчёта.';
    } else {
        text += `Обнаружено отклонений: ${score.deviationCount}. `;
        text += `Индекс лабораторных отклонений: ${score.riskScore}/100 (${levelRu(score.riskLevel)}).\n`;
        if (score.topFactors.length > 0) {
            const factors = score.topFactors.slice(0, 3);
            text += `Наиболее значимые факторы: ${factors.join(', ')}.`;
        }
    }

    if (previousRiskScore !== null && previousRiskScore !== undefined && trend !== TREND_NONE) {
        text += `\n\nСравнение с предыдущим отчётом по пациенту: было ${previousRiskScore}, сейчас ${score.riskScore}. `;
        if (trend === TREND_IMPROVING) {
            text += 'Динамика: улучшение по сравнению с прошлым загрузочным отчётом.';
        } else if (trend === TREND_WORSENING) {
            text += 'Динамика: ухудшение по сравнению с прошлым загрузочным отчётом.';
        } else {
            text += 'Динамика: без существенных изменений.';
        }
    }

    text += '\n\nОтказ от ответственности: сервис не ставит диагнозы и не назначает лечение.';
    return text;
}

module.exports = {
    TREND_NONE,
    TREND_IMPROVING,
    TREND_WORSENING,
    TREND_STABLE,
    compute,
    compareTrend,
    deviationStrength,
    extractDeviations,
    buildExplanation,
};
