package org.example.service.analytics;

import java.util.*;

public final class AnalyticsScoring {

    public static final String TREND_NONE = "NONE";
    public static final String TREND_IMPROVING = "IMPROVING";
    public static final String TREND_WORSENING = "WORSENING";
    public static final String TREND_STABLE = "STABLE";

    private AnalyticsScoring() {
    }

    public record ScoreResult(
            int riskScore,
            String riskLevel,
            int deviationCount,
            Map<String, Double> markerStrengths,
            List<String> topFactors
    ) {
    }

public static ScoreResult compute(Map<String, Object> rowSlice) {
        List<Map<String, Object>> deviations = extractDeviations(rowSlice);
        if (deviations.isEmpty()) {
            return new ScoreResult(0, "LOW", 0, Map.of(), List.of());
        }

        Map<String, Double> strengths = new LinkedHashMap<>();
        double sumCapped = 0.0;
        for (Map<String, Object> d : deviations) {
            String name = String.valueOf(d.getOrDefault("analysis", "?"));
            double strength = deviationStrength(d);
            strengths.merge(name, strength, Math::max);
            sumCapped += Math.min(1.0, strength);
        }

        int n = deviations.size();
        double avgCapped = sumCapped / n;
        int raw = (int) Math.round(18.0 * n + 52.0 * avgCapped);
        int riskScore = Math.min(100, Math.max(0, raw));

        String level = riskScore <= 35 ? "LOW" : (riskScore <= 70 ? "MEDIUM" : "HIGH");

        List<String> top = strengths.entrySet().stream()
                .sorted((a, b) -> Double.compare(b.getValue(), a.getValue()))
                .limit(5)
                .map(Map.Entry::getKey)
                .toList();

        return new ScoreResult(riskScore, level, n, strengths, top);
    }

    public static String compareTrend(int currentScore, Integer previousScore) {
        if (previousScore == null) {
            return TREND_NONE;
        }
        int delta = currentScore - previousScore;
        if (delta <= -8) {
            return TREND_IMPROVING;
        }
        if (delta >= 8) {
            return TREND_WORSENING;
        }
        return TREND_STABLE;
    }

    static double deviationStrength(Map<String, Object> item) {
        Object v = item.get("value");
        Object minO = item.get("min");
        Object maxO = item.get("max");
        if (!(v instanceof Number) || !(minO instanceof Number) || !(maxO instanceof Number)) {
            return 0.5;
        }
        double value = ((Number) v).doubleValue();
        double min = ((Number) minO).doubleValue();
        double max = ((Number) maxO).doubleValue();
        double range = max - min;
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

    @SuppressWarnings("unchecked")
    static List<Map<String, Object>> extractDeviations(Map<String, Object> rowSlice) {
        if (rowSlice == null) {
            return List.of();
        }
        Object raw = rowSlice.get("outOfNorms");
        if (!(raw instanceof List<?> list)) {
            return List.of();
        }
        List<Map<String, Object>> out = new ArrayList<>();
        for (Object o : list) {
            if (o instanceof Map<?, ?> m) {
                out.add((Map<String, Object>) m);
            }
        }
        return out;
    }

    public static String buildExplanation(ScoreResult score, String trend, Integer previousRiskScore) {
        StringBuilder sb = new StringBuilder();
        sb.append("Оценка основана на количестве и силе отклонений показателей от референсных диапазонов в загруженном файле. ");
        sb.append("Это не диагноз и не замена очной консультации врача.\n\n");

        if (score.deviationCount() == 0) {
            sb.append("Все учтённые показатели в пределах нормы для данного отчёта.");
        } else {
            sb.append("Обнаружено отклонений: ").append(score.deviationCount()).append(". ");
            sb.append("Индекс лабораторных отклонений: ").append(score.riskScore()).append("/100 (")
                    .append(levelRu(score.riskLevel())).append(").\n");
            if (!score.topFactors().isEmpty()) {
                List<String> factors = score.topFactors();
                int n = Math.min(3, factors.size());
                sb.append("Наиболее значимые факторы: ");
                sb.append(String.join(", ", factors.subList(0, n))).append(".");
            }
        }

        if (previousRiskScore != null && !TREND_NONE.equals(trend)) {
            sb.append("\n\nСравнение с предыдущим отчётом по пациенту: было ").append(previousRiskScore)
                    .append(", сейчас ").append(score.riskScore()).append(". ");
            sb.append(switch (trend) {
                case TREND_IMPROVING -> "Динамика: улучшение по сравнению с прошлым загрузочным отчётом.";
                case TREND_WORSENING -> "Динамика: ухудшение по сравнению с прошлым загрузочным отчётом.";
                default -> "Динамика: без существенных изменений.";
            });
        }

        sb.append("\n\nОтказ от ответственности: сервис не ставит диагнозы и не назначает лечение.");
        return sb.toString();
    }

    private static String levelRu(String level) {
        return switch (level) {
            case "LOW" -> "минимальная выраженность отклонений";
            case "MEDIUM" -> "умеренная выраженность отклонений";
            case "HIGH" -> "выраженные отклонения";
            default -> level;
        };
    }
}
