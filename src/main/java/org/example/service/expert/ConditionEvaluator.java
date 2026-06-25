package org.example.service.expert;

import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

public final class ConditionEvaluator {

    public record EvalResult(boolean matched, Map<String, Object> matchedFacts) {
        public static EvalResult ofMiss() {
            return new EvalResult(false, Map.of());
        }
    }

    public EvalResult evaluate(Map<String, Object> condition, PatientFacts facts) {
        Map<String, Object> matched = new LinkedHashMap<>();
        boolean ok = evalNode(condition, facts, matched);
        if (!ok) {
            return EvalResult.ofMiss();
        }
        return new EvalResult(true, matched);
    }

    private boolean evalNode(Map<String, Object> node, PatientFacts facts, Map<String, Object> matched) {
        if (node == null || node.isEmpty()) {
            return false;
        }
        if (node.containsKey("all")) {
            return evalAll(asList(node.get("all")), facts, matched);
        }
        if (node.containsKey("any")) {
            return evalAny(asList(node.get("any")), facts, matched);
        }
        if (node.containsKey("not")) {
            Object inner = node.get("not");
            if (inner instanceof Map<?, ?> m) {
                Map<String, Object> tmp = new LinkedHashMap<>();
                @SuppressWarnings("unchecked")
                boolean innerOk = evalNode((Map<String, Object>) m, facts, tmp);
                return !innerOk;
            }
            return true;
        }
        if (node.containsKey("feature") && node.containsKey("op")) {
            return evalLeaf(node, facts, matched);
        }
        return false;
    }

    private boolean evalAll(List<Map<String, Object>> children, PatientFacts facts, Map<String, Object> matched) {
        if (children.isEmpty()) {
            return false;
        }
        for (Map<String, Object> c : children) {
            Map<String, Object> tmp = new LinkedHashMap<>();
            if (!evalNode(c, facts, tmp)) {
                return false;
            }
            matched.putAll(tmp);
        }
        return true;
    }

    private boolean evalAny(List<Map<String, Object>> children, PatientFacts facts, Map<String, Object> matched) {
        if (children.isEmpty()) {
            return false;
        }
        for (Map<String, Object> c : children) {
            Map<String, Object> tmp = new LinkedHashMap<>();
            if (evalNode(c, facts, tmp)) {
                matched.putAll(tmp);
                return true;
            }
        }
        return false;
    }

    private boolean evalLeaf(Map<String, Object> leaf, PatientFacts facts, Map<String, Object> matched) {
        String feature = Objects.toString(leaf.get("feature"), null);
        String op = Objects.toString(leaf.get("op"), null);
        if (feature == null || op == null) {
            return false;
        }
        Object factValue = facts.get(feature);
        Object expected = leaf.get("value");
        Object expectedList = leaf.get("values");
        boolean ok = switch (op) {
            case "present" -> factValue != null;
            case "absent" -> factValue == null;
            case "eq" -> equalsLoose(factValue, expected);
            case "neq" -> factValue != null && !equalsLoose(factValue, expected);
            case "gt" -> compareNumeric(factValue, expected, c -> c > 0);
            case "gte" -> compareNumeric(factValue, expected, c -> c >= 0);
            case "lt" -> compareNumeric(factValue, expected, c -> c < 0);
            case "lte" -> compareNumeric(factValue, expected, c -> c <= 0);
            case "in" -> inList(factValue, expectedList);
            case "not_in" -> factValue != null && !inList(factValue, expectedList);
            case "range" -> inRange(factValue, expectedList, true);
            case "out_of_range" -> factValue != null && !inRange(factValue, expectedList, true);
            default -> false;
        };
        if (ok) {
            matched.put(feature, factValue);
        }
        return ok;
    }

    private static boolean equalsLoose(Object a, Object b) {
        if (a == null || b == null) {
            return a == b;
        }
        if (a instanceof Number && b instanceof Number) {
            return Double.compare(((Number) a).doubleValue(), ((Number) b).doubleValue()) == 0;
        }
        return Objects.equals(String.valueOf(a), String.valueOf(b));
    }

    private static boolean compareNumeric(Object a, Object b, java.util.function.IntPredicate cmp) {
        Double x = toDouble(a);
        Double y = toDouble(b);
        if (x == null || y == null) {
            return false;
        }
        return cmp.test(Double.compare(x, y));
    }

    private static Double toDouble(Object o) {
        if (o == null) return null;
        if (o instanceof Number n) return n.doubleValue();
        try {
            return Double.parseDouble(String.valueOf(o));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static boolean inList(Object value, Object list) {
        if (value == null || !(list instanceof Collection<?> c) || c.isEmpty()) {
            return false;
        }
        for (Object item : c) {
            if (equalsLoose(value, item)) {
                return true;
            }
        }
        return false;
    }

    private static boolean inRange(Object value, Object listOrPair, boolean inclusive) {
        if (value == null || !(listOrPair instanceof List<?> pair) || pair.size() != 2) {
            return false;
        }
        Double v = toDouble(value);
        Double lo = toDouble(pair.get(0));
        Double hi = toDouble(pair.get(1));
        if (v == null || lo == null || hi == null) {
            return false;
        }
        return inclusive ? (v >= lo && v <= hi) : (v > lo && v < hi);
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> asList(Object o) {
        if (!(o instanceof List<?> list)) {
            return List.of();
        }
        List<Map<String, Object>> out = new ArrayList<>();
        for (Object item : list) {
            if (item instanceof Map<?, ?> m) {
                out.add((Map<String, Object>) m);
            }
        }
        return out;
    }
}
