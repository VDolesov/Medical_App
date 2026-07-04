package org.example.controller;

import org.example.security.CurrentUserContext;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.config.OpenApiConfig;
import org.example.model.AnalysisReport;
import org.example.model.ClinicalRule;
import org.example.model.ClinicalSource;
import org.example.model.ReportPatient;
import org.example.model.RuleExecution;
import org.example.model.User;
import org.example.model.enums.Role;
import org.example.repository.AnalysisReportRepository;
import org.example.repository.ClinicalRuleRepository;
import org.example.repository.ClinicalSourceRepository;
import org.example.repository.ReportPatientRepository;
import org.example.repository.RuleExecutionRepository;
import org.example.repository.UserRepository;
import org.example.service.expert.ExpertSystemService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@Tag(name = OpenApiConfig.TAG_EXPERT)
public class ExpertController {

    private final ClinicalRuleRepository ruleRepository;
    private final ClinicalSourceRepository sourceRepository;
    private final RuleExecutionRepository executionRepository;
    private final ReportPatientRepository reportPatientRepository;
    private final AnalysisReportRepository reportRepository;
    private final UserRepository userRepository;
    private final ExpertSystemService expertSystemService;

    public ExpertController(ClinicalRuleRepository ruleRepository,
                            ClinicalSourceRepository sourceRepository,
                            RuleExecutionRepository executionRepository,
                            ReportPatientRepository reportPatientRepository,
                            AnalysisReportRepository reportRepository,
                            UserRepository userRepository,
                            ExpertSystemService expertSystemService) {
        this.ruleRepository = ruleRepository;
        this.sourceRepository = sourceRepository;
        this.executionRepository = executionRepository;
        this.reportPatientRepository = reportPatientRepository;
        this.reportRepository = reportRepository;
        this.userRepository = userRepository;
        this.expertSystemService = expertSystemService;
    }

    @GetMapping("/expert/rules")
    @Operation(
            summary = "Каталог клинических правил",
            description = """
                    Возвращает активные правила экспертной системы с их условиями (`conditionJson`),
                    действиями (`actionJson`), обоснованием и ссылкой на источник (клинические рекомендации).
                    Доступно врачу и администратору. Используется в админ-панели для просмотра базы знаний.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Массив правил, отсортирован по приоритету"),
            @ApiResponse(responseCode = "403", description = "Роль PATIENT")
    })
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ResponseEntity<?> listRules() {
        Map<Long, ClinicalSource> sources = new HashMap<>();
        for (ClinicalSource s : sourceRepository.findAll()) {
            sources.put(s.getId(), s);
        }
        List<ClinicalRule> rules = ruleRepository.findByActiveTrueOrderByPriorityAsc();
        List<Map<String, Object>> out = new ArrayList<>();
        for (ClinicalRule r : rules) {
            ClinicalSource src = r.getSourceId() == null ? null : sources.get(r.getSourceId());
            Map<String, Object> v = new HashMap<>();
            v.put("id", r.getId());
            v.put("code", r.getCode());
            v.put("title", r.getTitle());
            v.put("category", r.getCategory());
            v.put("severity", r.getSeverity());
            v.put("priority", r.getPriority());
            v.put("rationale", r.getRationale());
            v.put("patientMessage", r.getPatientMessage());
            v.put("sourceCode", src == null ? null : src.getCode());
            v.put("sourceTitle", src == null ? null : src.getTitle());
            v.put("sourceUrl", src == null ? null : src.getUrl());
            v.put("sourceSection", r.getSourceSection());
            v.put("conditionJson", r.getConditionJson());
            v.put("actionJson", r.getActionJson());
            out.add(v);
        }
        return ResponseEntity.ok(out);
    }

    @GetMapping("/expert/sources")
    @Operation(
            summary = "Источники клинических знаний",
            description = "Возвращает список Клинических Рекомендаций РФ, на которые опираются правила.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Массив источников"),
            @ApiResponse(responseCode = "403", description = "Роль PATIENT")
    })
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ResponseEntity<?> listSources() {
        return ResponseEntity.ok(sourceRepository.findAll());
    }

    @GetMapping("/expert/report-patient/{reportPatientId}/executions")
    @Operation(
            summary = "Выводы экспертной системы по пациенту в отчёте",
            description = """
                    Возвращает список сработавших правил для конкретной строки отчёта с обоснованием
                    и общим уровнем критичности (`overallSeverity`: INFO/WARNING/CRITICAL).
                    Пациент видит мягкие формулировки (`patientExplanation` вместо `explanationText`),
                    врач и админ — полный набор полей вместе с привязкой к источнику.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Объект с executions, triggeredCount, overallSeverity"),
            @ApiResponse(responseCode = "403", description = "Нет доступа к этой строке"),
            @ApiResponse(responseCode = "404", description = "Строка отчёта не найдена")
    })
    public ResponseEntity<?> executionsForReportPatient(
            @Parameter(description = "ID строки отчёта (report_patient.id)") @PathVariable Long reportPatientId) {
        Long userId = CurrentUserContext.currentUserId();
        ReportPatient rp = reportPatientRepository.findById(reportPatientId).orElse(null);
        if (rp == null) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
        if (!canViewReportPatient(rp, userId)) {
            return ResponseEntity.status(403).body(Map.of("error", "Forbidden"));
        }

        boolean asPatient = CurrentUserContext.hasRole(Role.PATIENT);
        Map<Long, ClinicalRule> ruleById = new HashMap<>();
        for (ClinicalRule r : ruleRepository.findAll()) {
            ruleById.put(r.getId(), r);
        }
        Map<Long, ClinicalSource> sources = new HashMap<>();
        for (ClinicalSource s : sourceRepository.findAll()) {
            sources.put(s.getId(), s);
        }

        List<RuleExecution> execs = executionRepository.findByReportPatientIdAndTriggeredTrueOrderByCreatedAtDesc(reportPatientId);
        List<Map<String, Object>> out = new ArrayList<>();
        for (RuleExecution e : execs) {
            ClinicalRule r = ruleById.get(e.getRuleId());
            ClinicalSource src = r == null || r.getSourceId() == null ? null : sources.get(r.getSourceId());
            Map<String, Object> v = new HashMap<>();
            v.put("ruleCode", e.getRuleCode());
            v.put("severity", e.getSeverity());
            v.put("ruleTitle", r == null ? null : r.getTitle());
            v.put("category", r == null ? null : r.getCategory());
            v.put("explanation", asPatient ? e.getPatientExplanationText() : e.getExplanationText());
            if (!asPatient) {
                v.put("patientExplanation", e.getPatientExplanationText());
                v.put("matchedFacts", e.getMatchedFactsJson());
                v.put("actionJson", r == null ? null : r.getActionJson());
                v.put("sourceCode", src == null ? null : src.getCode());
                v.put("sourceTitle", src == null ? null : src.getTitle());
                v.put("sourceUrl", src == null ? null : src.getUrl());
                v.put("sourceSection", r == null ? null : r.getSourceSection());
            }
            v.put("createdAt", e.getCreatedAt() == null ? null : e.getCreatedAt().toString());
            out.add(v);
        }
        out.sort(Comparator.comparing(m -> severityWeight((String) m.get("severity")), Comparator.reverseOrder()));

        String overallSeverity = out.stream()
                .map(m -> (String) m.get("severity"))
                .max(Comparator.comparingInt(ExpertController::severityWeight))
                .orElse("INFO");

        Map<String, Object> resp = new HashMap<>();
        resp.put("reportPatientId", reportPatientId);
        resp.put("overallSeverity", overallSeverity);
        resp.put("triggeredCount", out.size());
        resp.put("executions", out);
        return ResponseEntity.ok(resp);
    }

    @PostMapping("/expert/report-patient/{reportPatientId}/re-evaluate")
    @Operation(
            summary = "Перезапустить экспертную систему по пациенту",
            description = """
                    Полностью пересчитывает правила для одной строки отчёта и обновляет таблицу
                    `rule_executions`. Имеет смысл после правки правил или добавления новых.
                    Доступно врачу и администратору.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Пересчёт выполнен; в ответе — общее число сработавших правил"),
            @ApiResponse(responseCode = "403", description = "Роль PATIENT или нет доступа"),
            @ApiResponse(responseCode = "404", description = "Строка отчёта не найдена")
    })
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ResponseEntity<?> reEvaluate(
            @Parameter(description = "ID строки отчёта") @PathVariable Long reportPatientId) {
        ReportPatient rp = reportPatientRepository.findById(reportPatientId).orElse(null);
        if (rp == null) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
        if (!canViewReportPatient(rp, CurrentUserContext.currentUserId())) {
            return ResponseEntity.status(403).body(Map.of("error", "Forbidden"));
        }
        ExpertSystemService.PatientInferenceResult result = expertSystemService.runForReportPatient(reportPatientId);
        return ResponseEntity.ok(Map.of(
                "reportPatientId", result.reportPatientId(),
                "overallSeverity", result.overallSeverity(),
                "triggeredCount", result.triggeredRules().size()
        ));
    }

    private boolean canViewReportPatient(ReportPatient rp, Long userId) {
        if (CurrentUserContext.isAdmin()) return true;
        AnalysisReport report = reportRepository.findById(rp.getReportId()).orElse(null);
        if (report == null) return false;
        if (CurrentUserContext.hasRole(Role.PATIENT)) {
            Optional<User> u = userRepository.findById(userId);
            return u.isPresent() && rp.getPatientId() != null && rp.getPatientId().equals(u.get().getPatientId());
        }
        return report.getUserId() != null && report.getUserId().equals(userId);
    }

    private static int severityWeight(String severity) {
        if (severity == null) return 0;
        return switch (severity) {
            case "CRITICAL" -> 3;
            case "WARNING" -> 2;
            case "INFO" -> 1;
            default -> 0;
        };
    }
}
