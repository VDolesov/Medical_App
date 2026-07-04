package org.example.service.expert;

import org.example.model.Patient;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;

@Component
public class FactsBuilder {

    public PatientFacts build(Patient patient, Map<String, Object> currentSlice, Map<String, Object> previousSlice) {
        PatientFacts facts = new PatientFacts();

        if (patient != null) {
            facts.put(PatientFacts.Keys.AGE, patient.getAge());
            facts.put(PatientFacts.Keys.GENDER, patient.getGender());
        }

        applyMeasurementsFromSlice(currentSlice, facts);
        applyExtraFromSlice(currentSlice, facts);
        applyDeltasFromPrevious(currentSlice, previousSlice, facts);

        return facts;
    }

    private void applyMeasurementsFromSlice(Map<String, Object> slice, PatientFacts facts) {
        if (slice == null) return;
        Object raw = slice.get("measurements");
        if (!(raw instanceof List<?> list)) return;
        for (Object item : list) {
            if (!(item instanceof Map<?, ?> rawMap)) continue;
            String analysis = Objects.toString(rawMap.get("analysis"), "");
            Object value = rawMap.get("value");
            if (analysis.isBlank() || value == null) continue;

            MarkerKey key = resolveMarker(analysis);
            if (key == null) continue;

            facts.put(key.factKey(), value);
        }
    }

    private void applyExtraFromSlice(Map<String, Object> slice, PatientFacts facts) {
        if (slice == null) return;
        copyIfPresent(slice, "tnm_t_pre", facts, PatientFacts.Keys.TNM_T_PRE);
        copyIfPresent(slice, "tnm_n_pre", facts, PatientFacts.Keys.TNM_N_PRE);
        copyIfPresent(slice, "tnm_m_pre", facts, PatientFacts.Keys.TNM_M_PRE);
        copyIfPresent(slice, "tnm_t_post", facts, PatientFacts.Keys.TNM_T_POST);
        copyIfPresent(slice, "tnm_n_post", facts, PatientFacts.Keys.TNM_N_POST);
        copyIfPresent(slice, "tnm_m_post", facts, PatientFacts.Keys.TNM_M_POST);
        copyIfPresent(slice, "bethesda", facts, PatientFacts.Keys.BETHESDA);
        copyIfPresent(slice, "operation_type", facts, PatientFacts.Keys.OPERATION_TYPE);
        copyIfPresent(slice, "hospital_stay_days", facts, PatientFacts.Keys.HOSPITAL_STAY_DAYS);
        copyIfPresent(slice, "disease_duration_months", facts, PatientFacts.Keys.DISEASE_DURATION_MONTHS);
        copyIfPresent(slice, "comorbidity_cv", facts, PatientFacts.Keys.COMORBIDITY_CV);
        copyIfPresent(slice, "comorbidity_gi", facts, PatientFacts.Keys.COMORBIDITY_GI);
        copyIfPresent(slice, "comorbidity_resp", facts, PatientFacts.Keys.COMORBIDITY_RESP);
    }

    private static void copyIfPresent(Map<String, Object> src, String srcKey, PatientFacts dst, String factKey) {
        Object v = src.get(srcKey);
        if (v != null) {
            dst.put(factKey, v);
        }
    }

    private void applyDeltasFromPrevious(Map<String, Object> current, Map<String, Object> previous, PatientFacts facts) {
        Double curCalc = extractMeasurement(current, "calcitonin");
        Double prevCalc = extractMeasurement(previous, "calcitonin");
        if (curCalc != null && prevCalc != null) {
            facts.put(PatientFacts.Keys.CALCITONIN_DELTA, curCalc - prevCalc);
        }
        Double curTg = extractMeasurement(current, "antibody_to_tg");
        Double prevTg = extractMeasurement(previous, "antibody_to_tg");
        if (curTg != null && prevTg != null) {
            facts.put(PatientFacts.Keys.ANTIBODY_TO_TG_DELTA, curTg - prevTg);
        }
        Double curCea = extractMeasurement(current, "cea");
        Double prevCea = extractMeasurement(previous, "cea");
        if (curCea != null && prevCea != null) {
            facts.put(PatientFacts.Keys.CEA_DELTA, curCea - prevCea);
        }
        Double curTsh = extractMeasurement(current, "tsh");
        Double prevTsh = extractMeasurement(previous, "tsh");
        if (curTsh != null && prevTsh != null) {
            facts.put(PatientFacts.Keys.TSH_DELTA, curTsh - prevTsh);
        }
    }

    private static Double extractMeasurement(Map<String, Object> slice, String markerBase) {
        if (slice == null) return null;
        Object raw = slice.get("measurements");
        if (!(raw instanceof List<?> list)) return null;
        for (Object item : list) {
            if (!(item instanceof Map<?, ?> m)) continue;
            String analysis = Objects.toString(m.get("analysis"), "");
            MarkerKey k = resolveMarker(analysis);
            if (k == null) continue;
            if (!k.base().equals(markerBase) || !k.postOp()) continue;
            Object v = m.get("value");
            if (v instanceof Number n) return n.doubleValue();
            try {
                return Double.parseDouble(String.valueOf(v));
            } catch (NumberFormatException e) {
                return null;
            }
        }
        return null;
    }

    private record MarkerKey(String base, boolean postOp) {
        String factKey() {
            return base + (postOp ? "_post" : "_pre");
        }
    }

    static MarkerKey resolveMarker(String analysisName) {
        if (analysisName == null) return null;
        String norm = analysisName.trim().toLowerCase(Locale.ROOT);
        boolean post = norm.contains("после операции");
        norm = norm.replace("после операции", "").trim();
        norm = norm.replaceAll("\\s*\\(.*?\\)\\s*", "").trim();
        norm = norm.replaceAll("\\s*,.*", "").trim();
        String base = switch (norm) {
            case "ттг" -> "tsh";
            case "т4 свободный", "т4" -> "t4_free";
            case "кальцитонин" -> "calcitonin";
            case "паратгормон" -> "parathyroid";
            case "антитела к тиреоглобулину" -> "antibody_to_tg";
            case "рэа" -> "cea";
            case "кальций общий" -> "calcium";
            case "щелочная фосфатаза" -> "alp";
            default -> null;
        };
        return base == null ? null : new MarkerKey(base, post);
    }
}
