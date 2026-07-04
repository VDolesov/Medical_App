package org.example.service.expert;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

@DisplayName("ConditionEvaluator — интерпретатор DSL клинических правил")
class ConditionEvaluatorTest {

    private final ConditionEvaluator evaluator = new ConditionEvaluator();

    private static Map<String, Object> leaf(String feature, String op, Object value) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("feature", feature);
        m.put("op", op);
        m.put("value", value);
        return m;
    }

    private static Map<String, Object> leafNoValue(String feature, String op) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("feature", feature);
        m.put("op", op);
        return m;
    }

    private static Map<String, Object> leafValues(String feature, String op, List<?> values) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("feature", feature);
        m.put("op", op);
        m.put("values", values);
        return m;
    }

    @SafeVarargs
    private static Map<String, Object> group(String operator, Map<String, Object>... nodes) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put(operator, List.of(nodes));
        return m;
    }

    private static Map<String, Object> not(Map<String, Object> inner) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("not", inner);
        return m;
    }

    private static PatientFacts facts(Object... keyValuePairs) {
        PatientFacts f = new PatientFacts();
        for (int i = 0; i + 1 < keyValuePairs.length; i += 2) {
            f.put(String.valueOf(keyValuePairs[i]), keyValuePairs[i + 1]);
        }
        return f;
    }

    @Nested
    @DisplayName("Листовые операторы сравнения")
    class ComparisonOperators {

        @Test
        @DisplayName("eq: точное числовое совпадение засчитывается")
        void eq_exactNumericMatch_isTrue() {
            var result = evaluator.evaluate(leaf("tsh_post", "eq", 2.0), facts("tsh_post", 2.0));

            assertThat(result.matched()).isTrue();
        }

        @Test
        @DisplayName("eq: целое и дробное с одинаковым значением считаются равными (5 и 5.0)")
        void eq_intVsDouble_isTrue() {
            var result = evaluator.evaluate(leaf("bethesda", "eq", 5), facts("bethesda", 5.0));

            assertThat(result.matched()).isTrue();
        }

        @Test
        @DisplayName("eq: число и его строковое представление равны (loose-сравнение)")
        void eq_numberVsString_isTrue() {
            var result = evaluator.evaluate(leaf("bethesda", "eq", "5"), facts("bethesda", 5));

            assertThat(result.matched()).isTrue();
        }

        @ParameterizedTest(name = "[{index}] {0} {1} {2}, факт={3} → ожидается {4}")
        @CsvSource({
                "tsh_post,     gt,  2.0, 2.5, true",
                "tsh_post,     gt,  2.0, 2.0, false",
                "tsh_post,     gte, 2.0, 2.0, true",
                "tsh_post,     gte, 2.0, 1.9, false",
                "tsh_post,     lt,  0.1, 0.05, true",
                "tsh_post,     lt,  0.1, 0.10, false",
                "tsh_post,     lte, 0.1, 0.10, true",
                "calcium_post, neq, 2.2, 2.4, true",
                "calcium_post, neq, 2.2, 2.2, false",
        })
        @DisplayName("граничные значения операторов сравнения")
        void comparisonOperators_boundaryValues(String feature, String op,
                                                double expected, double fact, boolean shouldMatch) {
            var result = evaluator.evaluate(leaf(feature, op, expected), facts(feature, fact));

            assertThat(result.matched()).isEqualTo(shouldMatch);
        }
    }

    @Nested
    @DisplayName("Операторы наличия значения")
    class PresenceOperators {

        @Test
        @DisplayName("present: факт задан → срабатывает")
        void present_factSet_isTrue() {
            var result = evaluator.evaluate(
                    leafNoValue("operation_type", "present"),
                    facts("operation_type", "тиреоидэктомия"));

            assertThat(result.matched()).isTrue();
        }

        @Test
        @DisplayName("present: факт отсутствует → не срабатывает")
        void present_factMissing_isFalse() {
            var result = evaluator.evaluate(leafNoValue("operation_type", "present"), facts());

            assertThat(result.matched()).isFalse();
        }

        @Test
        @DisplayName("absent: факт отсутствует → срабатывает")
        void absent_factMissing_isTrue() {
            var result = evaluator.evaluate(leafNoValue("cea_post", "absent"), facts());

            assertThat(result.matched()).isTrue();
        }

        @Test
        @DisplayName("absent: факт задан → не срабатывает")
        void absent_factSet_isFalse() {
            var result = evaluator.evaluate(leafNoValue("cea_post", "absent"), facts("cea_post", 3.0));

            assertThat(result.matched()).isFalse();
        }
    }

    @Nested
    @DisplayName("Операторы принадлежности множеству")
    class SetOperators {

        @Test
        @DisplayName("in: значение входит в список")
        void in_valuePresent_isTrue() {
            var cond = leafValues("tnm_t_post", "in", List.of("T1", "T2"));

            assertThat(evaluator.evaluate(cond, facts("tnm_t_post", "T2")).matched()).isTrue();
        }

        @Test
        @DisplayName("in: значение не входит в список")
        void in_valueAbsent_isFalse() {
            var cond = leafValues("tnm_t_post", "in", List.of("T1", "T2"));

            assertThat(evaluator.evaluate(cond, facts("tnm_t_post", "T4")).matched()).isFalse();
        }

        @Test
        @DisplayName("in: пустой список значений → не срабатывает")
        void in_emptyValues_isFalse() {
            var cond = leafValues("tnm_t_post", "in", List.of());

            assertThat(evaluator.evaluate(cond, facts("tnm_t_post", "T2")).matched()).isFalse();
        }

        @Test
        @DisplayName("not_in: значение вне списка → срабатывает")
        void notIn_valueOutsideList_isTrue() {
            var cond = leafValues("tnm_n_post", "not_in", List.of("N0", "Nx"));

            assertThat(evaluator.evaluate(cond, facts("tnm_n_post", "N1")).matched()).isTrue();
        }

        @Test
        @DisplayName("not_in: факт отсутствует → не срабатывает (нечему быть вне множества)")
        void notIn_factMissing_isFalse() {
            var cond = leafValues("tnm_n_post", "not_in", List.of("N0"));

            assertThat(evaluator.evaluate(cond, facts()).matched()).isFalse();
        }
    }

    @Nested
    @DisplayName("Операторы диапазона")
    class RangeOperators {

        @Test
        @DisplayName("range: значение внутри диапазона")
        void range_valueInside_isTrue() {
            var cond = leafValues("tsh_post", "range", List.of(0.4, 4.0));

            assertThat(evaluator.evaluate(cond, facts("tsh_post", 2.0)).matched()).isTrue();
        }

        @Test
        @DisplayName("range: значение на нижней границе входит (включительно)")
        void range_lowerBoundary_isTrue() {
            var cond = leafValues("tsh_post", "range", List.of(0.4, 4.0));

            assertThat(evaluator.evaluate(cond, facts("tsh_post", 0.4)).matched()).isTrue();
        }

        @Test
        @DisplayName("range: значение за пределами диапазона не входит")
        void range_valueOutside_isFalse() {
            var cond = leafValues("tsh_post", "range", List.of(0.4, 4.0));

            assertThat(evaluator.evaluate(cond, facts("tsh_post", 9.0)).matched()).isFalse();
        }

        @Test
        @DisplayName("range: некорректное число границ (не пара) → не срабатывает")
        void range_wrongArity_isFalse() {
            var cond = leafValues("tsh_post", "range", List.of(0.4, 4.0, 9.0));

            assertThat(evaluator.evaluate(cond, facts("tsh_post", 2.0)).matched()).isFalse();
        }

        @Test
        @DisplayName("out_of_range: значение вне диапазона → срабатывает")
        void outOfRange_valueOutside_isTrue() {
            var cond = leafValues("calcium_post", "out_of_range", List.of(2.15, 2.6));

            assertThat(evaluator.evaluate(cond, facts("calcium_post", 1.9)).matched()).isTrue();
        }

        @Test
        @DisplayName("out_of_range: значение внутри диапазона → не срабатывает")
        void outOfRange_valueInside_isFalse() {
            var cond = leafValues("calcium_post", "out_of_range", List.of(2.15, 2.6));

            assertThat(evaluator.evaluate(cond, facts("calcium_post", 2.3)).matched()).isFalse();
        }
    }

    @Nested
    @DisplayName("Логический оператор ALL (конъюнкция)")
    class AllOperator {

        @Test
        @DisplayName("все под-условия истинны → ALL срабатывает")
        void all_everyChildTrue_isTrue() {
            var cond = group("all",
                    leaf("tnm_t_post", "eq", "T3"),
                    leaf("calcium_post", "lt", 2.15));

            var result = evaluator.evaluate(cond, facts("tnm_t_post", "T3", "calcium_post", 2.0));

            assertThat(result.matched()).isTrue();
        }

        @Test
        @DisplayName("хотя бы одно под-условие ложно → ALL не срабатывает")
        void all_oneChildFalse_isFalse() {
            var cond = group("all",
                    leaf("tnm_t_post", "eq", "T3"),
                    leaf("calcium_post", "lt", 2.15));

            var result = evaluator.evaluate(cond, facts("tnm_t_post", "T3", "calcium_post", 2.4));

            assertThat(result.matched()).isFalse();
        }

        @Test
        @DisplayName("пустой список ALL → не срабатывает (защита от пустого правила)")
        void all_emptyChildren_isFalse() {
            assertThat(evaluator.evaluate(group("all"), facts()).matched()).isFalse();
        }
    }

    @Nested
    @DisplayName("Логический оператор ANY (дизъюнкция)")
    class AnyOperator {

        @Test
        @DisplayName("хотя бы одно под-условие истинно → ANY срабатывает")
        void any_oneChildTrue_isTrue() {
            var cond = group("any",
                    leaf("tnm_m_post", "eq", "M1"),
                    leaf("tnm_t_post", "eq", "T4"));

            assertThat(evaluator.evaluate(cond, facts("tnm_t_post", "T4")).matched()).isTrue();
        }

        @Test
        @DisplayName("все под-условия ложны → ANY не срабатывает")
        void any_allChildrenFalse_isFalse() {
            var cond = group("any",
                    leaf("tnm_m_post", "eq", "M1"),
                    leaf("tnm_t_post", "eq", "T4"));

            assertThat(evaluator.evaluate(cond, facts("tnm_t_post", "T1")).matched()).isFalse();
        }

        @Test
        @DisplayName("пустой список ANY → не срабатывает")
        void any_emptyChildren_isFalse() {
            assertThat(evaluator.evaluate(group("any"), facts()).matched()).isFalse();
        }
    }

    @Nested
    @DisplayName("Логический оператор NOT (отрицание)")
    class NotOperator {

        @Test
        @DisplayName("NOT над ложным условием → срабатывает")
        void not_overFalseCondition_isTrue() {
            var cond = not(leaf("tnm_m_post", "eq", "M1"));

            assertThat(evaluator.evaluate(cond, facts("tnm_m_post", "M0")).matched()).isTrue();
        }

        @Test
        @DisplayName("NOT над истинным условием → не срабатывает")
        void not_overTrueCondition_isFalse() {
            var cond = not(leaf("tnm_m_post", "eq", "M1"));

            assertThat(evaluator.evaluate(cond, facts("tnm_m_post", "M1")).matched()).isFalse();
        }
    }

    @Nested
    @DisplayName("Вложенные деревья условий")
    class NestedConditions {

        @Test
        @DisplayName("ANY над ALL: форма реального правила R-002")
        void anyOverAll_realRuleShape() {
            var cond = group("any",
                    leaf("tnm_t_post", "eq", "T3"),
                    group("all",
                            leaf("antibody_to_tg_post", "gt", 115),
                            leaf("antibody_to_tg_delta", "gt", 30)));

            var triggeredByStage = facts("tnm_t_post", "T3");
            var triggeredByMarkers = facts("antibody_to_tg_post", 200, "antibody_to_tg_delta", 50);
            var notTriggered = facts("antibody_to_tg_post", 200, "antibody_to_tg_delta", 5);

            assertThat(evaluator.evaluate(cond, triggeredByStage).matched()).isTrue();
            assertThat(evaluator.evaluate(cond, triggeredByMarkers).matched()).isTrue();
            assertThat(evaluator.evaluate(cond, notTriggered).matched()).isFalse();
        }

        @Test
        @DisplayName("ALL с вложенным NOT")
        void allWithNestedNot() {
            var cond = group("all",
                    leaf("tnm_t_post", "eq", "T1"),
                    not(leaf("tnm_m_post", "eq", "M1")));

            assertThat(evaluator.evaluate(cond, facts("tnm_t_post", "T1", "tnm_m_post", "M0")).matched()).isTrue();
            assertThat(evaluator.evaluate(cond, facts("tnm_t_post", "T1", "tnm_m_post", "M1")).matched()).isFalse();
        }
    }

    @Nested
    @DisplayName("Накопление сработавших фактов (объяснимость правил)")
    class MatchedFacts {

        @Test
        @DisplayName("ALL: в matchedFacts попадают факты всех сработавших листьев")
        void all_collectsEveryLeafFact() {
            var cond = group("all",
                    leaf("tnm_t_post", "eq", "T3"),
                    leaf("calcium_post", "lt", 2.15));

            var result = evaluator.evaluate(cond, facts("tnm_t_post", "T3", "calcium_post", 2.0));

            assertThat(result.matched()).isTrue();
            assertThat(result.matchedFacts())
                    .containsEntry("tnm_t_post", "T3")
                    .containsEntry("calcium_post", 2.0);
        }

        @Test
        @DisplayName("ANY: в matchedFacts попадает только сработавшая ветка")
        void any_collectsOnlyMatchedBranch() {
            var cond = group("any",
                    leaf("tnm_m_post", "eq", "M1"),
                    leaf("tnm_t_post", "eq", "T4"));

            var result = evaluator.evaluate(cond, facts("tnm_t_post", "T4", "tnm_m_post", "M0"));

            assertThat(result.matchedFacts())
                    .containsEntry("tnm_t_post", "T4")
                    .doesNotContainKey("tnm_m_post");
        }

        @Test
        @DisplayName("промах правила возвращает пустой набор фактов")
        void miss_returnsEmptyFacts() {
            var result = evaluator.evaluate(leaf("tsh_post", "gt", 10.0), facts("tsh_post", 1.0));

            assertThat(result.matched()).isFalse();
            assertThat(result.matchedFacts()).isEmpty();
        }
    }

    @Nested
    @DisplayName("Некорректный и пограничный ввод")
    class MalformedInput {

        @Test
        @DisplayName("null-условие → промах без исключения")
        void nullCondition_returnsMiss() {
            assertThat(evaluator.evaluate(null, facts()).matched()).isFalse();
        }

        @Test
        @DisplayName("пустое условие → промах")
        void emptyCondition_returnsMiss() {
            assertThat(evaluator.evaluate(Map.of(), facts()).matched()).isFalse();
        }

        @Test
        @DisplayName("неизвестный оператор → промах, без исключения")
        void unknownOperator_returnsMiss() {
            var cond = leaf("tsh_post", "approx", 2.0);

            assertThat(evaluator.evaluate(cond, facts("tsh_post", 2.0)).matched()).isFalse();
        }

        @Test
        @DisplayName("лист без ключа feature → промах")
        void leafWithoutFeature_returnsMiss() {
            Map<String, Object> malformed = new LinkedHashMap<>();
            malformed.put("op", "present");

            assertThat(evaluator.evaluate(malformed, facts("tsh_post", 1)).matched()).isFalse();
        }

        @Test
        @DisplayName("gt по нечисловому факту → промах (строку нельзя сравнить как число)")
        void gt_nonNumericFact_returnsMiss() {
            var cond = leaf("operation_type", "gt", 1);

            assertThat(evaluator.evaluate(cond, facts("operation_type", "тиреоидэктомия")).matched()).isFalse();
        }

        @Test
        @DisplayName("gt/gte при отсутствующем факте не срабатывают (fail-closed)")
        void comparison_missingFact_gtFamilyFailsClosed() {
            assertThat(evaluator.evaluate(leaf("tsh_post", "gt", 2.0), facts()).matched()).isFalse();
            assertThat(evaluator.evaluate(leaf("tsh_post", "gte", 2.0), facts()).matched()).isFalse();
        }

        @Test
        @DisplayName("lt/lte при отсутствующем факте не срабатывают (fail-closed, симметрично gt/gte)")
        void comparison_missingFact_ltFamilyFailsClosed() {
            assertThat(evaluator.evaluate(leaf("tsh_post", "lt", 0.1), facts()).matched()).isFalse();
            assertThat(evaluator.evaluate(leaf("tsh_post", "lte", 0.1), facts()).matched()).isFalse();
        }
    }
}
