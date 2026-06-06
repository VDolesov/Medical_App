package org.example.service.expert;

import java.util.LinkedHashMap;
import java.util.Map;

public final class PatientFacts {

    private final Map<String, Object> data = new LinkedHashMap<>();

    public PatientFacts put(String key, Object value) {
        data.put(key, value);
        return this;
    }

    public Object get(String key) {
        return data.get(key);
    }

    public boolean has(String key) {
        return data.containsKey(key) && data.get(key) != null;
    }

    public Map<String, Object> asMap() {
        return new LinkedHashMap<>(data);
    }

public static final class Keys {
        public static final String AGE = "age";
        public static final String GENDER = "gender";
        public static final String OPERATION_TYPE = "operation_type";
        public static final String DISEASE_DURATION_MONTHS = "disease_duration_months";
        public static final String HOSPITAL_STAY_DAYS = "hospital_stay_days";
        public static final String BETHESDA = "bethesda";

        public static final String TNM_T_PRE = "tnm_t_pre";
        public static final String TNM_N_PRE = "tnm_n_pre";
        public static final String TNM_M_PRE = "tnm_m_pre";
        public static final String TNM_T_POST = "tnm_t_post";
        public static final String TNM_N_POST = "tnm_n_post";
        public static final String TNM_M_POST = "tnm_m_post";

        public static final String ALP_PRE = "alp_pre";
        public static final String CALCIUM_PRE = "calcium_pre";
        public static final String TSH_PRE = "tsh_pre";
        public static final String T4_FREE_PRE = "t4_free_pre";
        public static final String CALCITONIN_PRE = "calcitonin_pre";
        public static final String PARATHYROID_PRE = "parathyroid_pre";
        public static final String ANTIBODY_TO_TG_PRE = "antibody_to_tg_pre";
        public static final String CEA_PRE = "cea_pre";

        public static final String ALP_POST = "alp_post";
        public static final String CALCIUM_POST = "calcium_post";
        public static final String TSH_POST = "tsh_post";
        public static final String T4_FREE_POST = "t4_free_post";
        public static final String CALCITONIN_POST = "calcitonin_post";
        public static final String PARATHYROID_POST = "parathyroid_post";
        public static final String ANTIBODY_TO_TG_POST = "antibody_to_tg_post";
        public static final String CEA_POST = "cea_post";

        public static final String CALCITONIN_DELTA = "calcitonin_delta";
        public static final String ANTIBODY_TO_TG_DELTA = "antibody_to_tg_delta";
        public static final String CEA_DELTA = "cea_delta";
        public static final String TSH_DELTA = "tsh_delta";

        public static final String COMORBIDITY_CV = "comorbidity_cv";
        public static final String COMORBIDITY_GI = "comorbidity_gi";
        public static final String COMORBIDITY_RESP = "comorbidity_resp";

        private Keys() {
        }
    }
}
