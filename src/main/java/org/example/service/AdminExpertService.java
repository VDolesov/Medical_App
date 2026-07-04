package org.example.service;

import org.example.model.ClinicalRule;
import org.example.model.ClinicalSource;
import org.example.repository.ClinicalRuleRepository;
import org.example.repository.ClinicalSourceRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

@Service
public class AdminExpertService {

    private static final Set<String> ALLOWED_SEVERITIES = Set.of("INFO", "WARNING", "CRITICAL");
    private static final Set<String> ALLOWED_OPS = Set.of(
            "eq", "neq", "gt", "gte", "lt", "lte", "in", "not_in",
            "range", "out_of_range", "present", "absent");

    private final ClinicalRuleRepository ruleRepository;
    private final ClinicalSourceRepository sourceRepository;

    public AdminExpertService(ClinicalRuleRepository ruleRepository, ClinicalSourceRepository sourceRepository) {
        this.ruleRepository = ruleRepository;
        this.sourceRepository = sourceRepository;
    }

    @Transactional
    public ClinicalRule create(Map<String, Object> body) {
        ClinicalRule rule = new ClinicalRule();
        applyFields(rule, body, true);
        return ruleRepository.save(rule);
    }

    @Transactional
    public ClinicalRule update(Long id, Map<String, Object> body) {
        ClinicalRule rule = ruleRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Правило не найдено: " + id));
        applyFields(rule, body, false);
        return ruleRepository.save(rule);
    }

    @Transactional
    public ClinicalRule setActive(Long id, boolean active) {
        ClinicalRule rule = ruleRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Правило не найдено: " + id));
        rule.setActive(active);
        return ruleRepository.save(rule);
    }

    @Transactional
    public void delete(Long id) {
        if (!ruleRepository.existsById(id)) {
            throw new IllegalArgumentException("Правило не найдено: " + id);
        }
        ruleRepository.deleteById(id);
    }

    @Transactional(readOnly = true)
    public List<ClinicalSource> listSources() {
        return sourceRepository.findAll();
    }

    @Transactional
    public ClinicalSource createSource(Map<String, Object> body) {
        ClinicalSource src = new ClinicalSource();
        applySource(src, body, true);
        return sourceRepository.save(src);
    }

    @Transactional
    public ClinicalSource updateSource(Long id, Map<String, Object> body) {
        ClinicalSource src = sourceRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Источник не найден: " + id));
        applySource(src, body, false);
        return sourceRepository.save(src);
    }

    private void applyFields(ClinicalRule rule, Map<String, Object> body, boolean creating) {
        if (creating) {
            String code = asString(body.get("code"));
            if (code == null || code.isBlank()) {
                throw new IllegalArgumentException("code обязателен");
            }
            if (ruleRepository.findByCode(code).isPresent()) {
                throw new IllegalArgumentException("Правило с кодом " + code + " уже существует");
            }
            rule.setCode(code.trim());
            rule.setActive(asBool(body.get("active"), true));
            rule.setPriority(asInt(body.get("priority"), 100));
        } else {
            if (body.containsKey("active")) {
                rule.setActive(asBool(body.get("active"), Boolean.TRUE.equals(rule.getActive())));
            }
            if (body.containsKey("priority")) {
                rule.setPriority(asInt(body.get("priority"), rule.getPriority()));
            }
        }

        String title = asString(body.get("title"));
        if (title == null || title.isBlank()) {
            throw new IllegalArgumentException("title обязателен");
        }
        rule.setTitle(title.trim());

        String category = asString(body.get("category"));
        rule.setCategory(category == null || category.isBlank() ? "GENERAL" : category.trim());

        String severity = asString(body.get("severity"));
        if (severity == null || !ALLOWED_SEVERITIES.contains(severity.trim().toUpperCase())) {
            throw new IllegalArgumentException("severity должен быть один из " + ALLOWED_SEVERITIES);
        }
        rule.setSeverity(severity.trim().toUpperCase());

        String rationale = asString(body.get("rationale"));
        rule.setRationale(rationale == null ? "" : rationale.trim());
        rule.setPatientMessage(asString(body.get("patientMessage")));

        Object src = body.get("sourceId");
        if (src instanceof Number n) {
            Long sourceId = n.longValue();
            if (!sourceRepository.existsById(sourceId)) {
                throw new IllegalArgumentException("Источник не найден: " + sourceId);
            }
            rule.setSourceId(sourceId);
        } else if (body.containsKey("sourceId")) {
            rule.setSourceId(null);
        }
        rule.setSourceSection(asString(body.get("sourceSection")));

        Object condition = body.get("conditionJson");
        if (!(condition instanceof Map<?, ?> condMap) || condMap.isEmpty()) {
            throw new IllegalArgumentException("conditionJson обязателен");
        }
        @SuppressWarnings("unchecked")
        Map<String, Object> condMapTyped = (Map<String, Object>) condMap;
        validateCondition(condMapTyped, 0);
        rule.setConditionJson(condMapTyped);

        Object action = body.get("actionJson");
        if (action instanceof Map<?, ?> actMap) {
            @SuppressWarnings("unchecked")
            Map<String, Object> actMapTyped = (Map<String, Object>) actMap;
            rule.setActionJson(actMapTyped);
        } else {
            rule.setActionJson(Map.of());
        }
    }

    private void applySource(ClinicalSource src, Map<String, Object> body, boolean creating) {
        if (creating) {
            String code = asString(body.get("code"));
            if (code == null || code.isBlank()) {
                throw new IllegalArgumentException("code обязателен");
            }
            if (sourceRepository.findByCode(code).isPresent()) {
                throw new IllegalArgumentException("Источник с кодом " + code + " уже существует");
            }
            src.setCode(code.trim());
        }
        String title = asString(body.get("title"));
        if (title == null || title.isBlank()) {
            throw new IllegalArgumentException("title обязателен");
        }
        src.setTitle(title.trim());
        src.setOrganization(asString(body.get("organization")));
        src.setUrl(asString(body.get("url")));
        src.setDescription(asString(body.get("description")));
        Object year = body.get("year");
        if (year instanceof Number n) {
            src.setYear(n.intValue());
        } else if (body.containsKey("year")) {
            src.setYear(null);
        }
    }

    private void validateCondition(Map<String, Object> node, int depth) {
        if (depth > 8) {
            throw new IllegalArgumentException("Слишком глубокая вложенность условия");
        }
        boolean hasAll = node.containsKey("all");
        boolean hasAny = node.containsKey("any");
        boolean hasNot = node.containsKey("not");
        boolean isLeaf = node.containsKey("feature") && node.containsKey("op");
        int kinds = (hasAll ? 1 : 0) + (hasAny ? 1 : 0) + (hasNot ? 1 : 0) + (isLeaf ? 1 : 0);
        if (kinds != 1) {
            throw new IllegalArgumentException("Узел условия должен иметь ровно один из all/any/not/leaf");
        }
        if (hasAll || hasAny) {
            Object children = node.get(hasAll ? "all" : "any");
            if (!(children instanceof List<?> list) || list.isEmpty()) {
                throw new IllegalArgumentException("Группа all/any не может быть пустой");
            }
            for (Object c : list) {
                if (!(c instanceof Map<?, ?> m)) {
                    throw new IllegalArgumentException("Элемент группы должен быть объектом");
                }
                @SuppressWarnings("unchecked")
                Map<String, Object> mt = (Map<String, Object>) m;
                validateCondition(mt, depth + 1);
            }
        } else if (hasNot) {
            if (!(node.get("not") instanceof Map<?, ?> m)) {
                throw new IllegalArgumentException("not должен оборачивать объект");
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> mt = (Map<String, Object>) m;
            validateCondition(mt, depth + 1);
        } else {
            String feature = asString(node.get("feature"));
            String op = asString(node.get("op"));
            if (feature == null || feature.isBlank()) {
                throw new IllegalArgumentException("feature обязателен в листе");
            }
            if (op == null || !ALLOWED_OPS.contains(op)) {
                throw new IllegalArgumentException("op должен быть один из " + ALLOWED_OPS);
            }
            boolean needsValue = Set.of("eq", "neq", "gt", "gte", "lt", "lte").contains(op);
            boolean needsValues = Set.of("in", "not_in", "range", "out_of_range").contains(op);
            if (needsValue && !node.containsKey("value")) {
                throw new IllegalArgumentException("op " + op + " требует поле value");
            }
            if (needsValues && !(node.get("values") instanceof List<?>)) {
                throw new IllegalArgumentException("op " + op + " требует массив values");
            }
        }
    }

    private static String asString(Object o) {
        return o == null ? null : Objects.toString(o, null);
    }

    private static int asInt(Object o, int def) {
        if (o instanceof Number n) return n.intValue();
        if (o == null) return def;
        try {
            return Integer.parseInt(o.toString());
        } catch (NumberFormatException e) {
            return def;
        }
    }

    private static boolean asBool(Object o, boolean def) {
        if (o instanceof Boolean b) return b;
        if (o == null) return def;
        return Boolean.parseBoolean(o.toString());
    }
}
