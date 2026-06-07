package org.example.service.expert;

import org.example.model.Patient;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

@DisplayName("FactsBuilder — сборка фактов пациента для экспертной системы")
class FactsBuilderTest {

    private final FactsBuilder builder = new FactsBuilder();

    private static Patient patient(int age, String gender) {
        Patient p = new Patient();
        p.setAge(age);
        p.setGender(gender);
        return p;
    }

    private static Map<String, Object> measurement(String analysis, double value) {
        return Map.of("analysis", analysis, "value", value);
    }

    private static Map<String, Object> sliceWithMeasurements(Map<String, Object>... measurements) {
        return Map.of("measurements", List.of(measurements));
    }

    @Nested
    @DisplayName("Демографические факты")
    class Demographics {

        @Test
        @DisplayName("возраст и пол пациента переносятся в факты")
        void patientAgeAndGender_copiedToFacts() {
            PatientFacts result = builder.build(patient(54, "FEMALE"), Map.of(), null);

            assertThat(result.get("age")).isEqualTo(54);
            assertThat(result.get("gender")).isEqualTo("FEMALE");
        }

        @Test
        @DisplayName("null-пациент не приводит к ошибке и не добавляет демографию")
        void nullPatient_handledGracefully() {
            PatientFacts result = builder.build(null, Map.of(), null);

            assertThat(result.has("age")).isFalse();
            assertThat(result.has("gender")).isFalse();
        }
    }

    @Nested
    @DisplayName("Лабораторные маркеры из measurements")
    class LabMarkers {

        @Test
        @DisplayName("«ТТГ после операции» распознаётся как послеоперационный маркер tsh_post")
        void postOpAnalysisName_mappedToPostKey() {
            Map<String, Object> slice = sliceWithMeasurements(measurement("ТТГ после операции", 5.0));

            PatientFacts result = builder.build(null, slice, null);

            assertThat(result.get("tsh_post")).isEqualTo(5.0);
            assertThat(result.has("tsh_pre")).isFalse();
        }

        @Test
        @DisplayName("«Кальцитонин» без пометки об операции распознаётся как дооперационный маркер")
        void preOpAnalysisName_mappedToPreKey() {
            Map<String, Object> slice = sliceWithMeasurements(measurement("Кальцитонин", 8.0));

            PatientFacts result = builder.build(null, slice, null);

            assertThat(result.get("calcitonin_pre")).isEqualTo(8.0);
        }

        @Test
        @DisplayName("неизвестное название анализа игнорируется без ошибки")
        void unknownAnalysisName_ignored() {
            Map<String, Object> slice = sliceWithMeasurements(measurement("Глюкоза", 8.0));

            PatientFacts result = builder.build(null, slice, null);

            assertThat(result.asMap()).isEmpty();
        }
    }

    @Nested
    @DisplayName("Дополнительные клинические поля")
    class ExtraFields {

        @Test
        @DisplayName("TNM-стадии, Bethesda и тип операции переносятся напрямую")
        void extraFields_copiedAsIs() {
            Map<String, Object> slice = Map.of(
                    "tnm_t_post", "T3",
                    "tnm_n_post", "N1",
                    "bethesda", 5,
                    "operation_type", "тиреоидэктомия");

            PatientFacts result = builder.build(null, slice, null);

            assertThat(result.get("tnm_t_post")).isEqualTo("T3");
            assertThat(result.get("tnm_n_post")).isEqualTo("N1");
            assertThat(result.get("bethesda")).isEqualTo(5);
            assertThat(result.get("operation_type")).isEqualTo("тиреоидэктомия");
        }
    }

    @Nested
    @DisplayName("Дельты показателей в динамике")
    class DynamicsDeltas {

        @Test
        @DisplayName("дельта кальцитонина считается как разница послеоперационных значений")
        void calcitoninDelta_computedFromPostOpValues() {
            Map<String, Object> current = sliceWithMeasurements(measurement("Кальцитонин после операции", 20.0));
            Map<String, Object> previous = sliceWithMeasurements(measurement("Кальцитонин после операции", 12.0));

            PatientFacts result = builder.build(null, current, previous);

            assertThat((Double) result.get("calcitonin_delta")).isEqualTo(8.0);
        }

        @Test
        @DisplayName("без предыдущего отчёта дельта не рассчитывается")
        void noPreviousSlice_noDelta() {
            Map<String, Object> current = sliceWithMeasurements(measurement("Кальцитонин после операции", 20.0));

            PatientFacts result = builder.build(null, current, null);

            assertThat(result.has("calcitonin_delta")).isFalse();
        }
    }

    @Nested
    @DisplayName("Устойчивость к пустому вводу")
    class NullSafety {

        @Test
        @DisplayName("null во всех аргументах не приводит к исключению")
        void allArgumentsNull_doesNotThrow() {
            assertThatCode(() -> builder.build(null, null, null)).doesNotThrowAnyException();
        }

        @Test
        @DisplayName("пустой срез даёт пустой набор фактов")
        void emptySlice_producesEmptyFacts() {
            PatientFacts result = builder.build(null, Map.of(), null);

            assertThat(result.asMap()).isEmpty();
        }
    }
}
