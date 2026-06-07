package org.example.service.analytics;

import org.junit.jupiter.api.Test;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class AnalyticsScoringTest {

    @Test
    void allInNorm_returnsZeroLow() {
        Map<String, Object> row = Map.of("outOfNorms", List.of("Все значения в норме"));
        AnalyticsScoring.ScoreResult r = AnalyticsScoring.compute(row);
        assertThat(r.riskScore()).isEqualTo(0);
        assertThat(r.riskLevel()).isEqualTo("LOW");
        assertThat(r.deviationCount()).isEqualTo(0);
    }

    @Test
    void oneDeviation_producesNonZeroScore() {
        Map<String, Object> dev = new LinkedHashMap<>();
        dev.put("analysis", "Глюкоза");
        dev.put("value", 8.0);
        dev.put("min", 3.9);
        dev.put("max", 6.1);
        Map<String, Object> row = Map.of("outOfNorms", List.of(dev));
        AnalyticsScoring.ScoreResult r = AnalyticsScoring.compute(row);
        assertThat(r.riskScore()).isGreaterThan(0);
        assertThat(r.deviationCount()).isEqualTo(1);
        assertThat(r.topFactors()).isNotEmpty();
    }

    @Test
    void trend_compare() {
        assertThat(AnalyticsScoring.compareTrend(30, 50)).isEqualTo(AnalyticsScoring.TREND_IMPROVING);
        assertThat(AnalyticsScoring.compareTrend(60, 40)).isEqualTo(AnalyticsScoring.TREND_WORSENING);
        assertThat(AnalyticsScoring.compareTrend(45, 44)).isEqualTo(AnalyticsScoring.TREND_STABLE);
        assertThat(AnalyticsScoring.compareTrend(10, null)).isEqualTo(AnalyticsScoring.TREND_NONE);
    }
}
