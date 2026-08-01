CREATE INDEX IF NOT EXISTS idx_analysis_reports_user_created
    ON analysis_reports (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_analysis_results_patient
    ON analysis_results (patient_id);

CREATE INDEX IF NOT EXISTS idx_analysis_results_norm
    ON analysis_results (norm_id);
