package org.example.service;

import org.example.model.AnalysisNorm;
import org.example.repository.AnalysisNormRepository;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class NormsService {

    private final AnalysisNormRepository normRepository;

    public NormsService(AnalysisNormRepository normRepository) {
        this.normRepository = normRepository;
    }

    @Cacheable("norms")
    public List<org.example.dto.NormDto> getAll() {
        return normRepository.findAll().stream()
                .map(org.example.dto.NormDto::from)
                .collect(Collectors.toList());
    }

    @CacheEvict(value = "norms", allEntries = true)
    public AnalysisNorm create(String name, Double minValue, Double maxValue, String unit) {
        validate(name, minValue, maxValue, unit);
        AnalysisNorm n = new AnalysisNorm();
        n.setName(name.trim());
        n.setMinValue(minValue);
        n.setMaxValue(maxValue);
        n.setUnit(unit.trim());
        return normRepository.save(n);
    }

    @CacheEvict(value = "norms", allEntries = true)
    public AnalysisNorm update(Long id, String name, Double minValue, Double maxValue, String unit) {
        validate(name, minValue, maxValue, unit);
        AnalysisNorm n = normRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Норма не найдена"));
        n.setName(name.trim());
        n.setMinValue(minValue);
        n.setMaxValue(maxValue);
        n.setUnit(unit.trim());
        return normRepository.save(n);
    }

    private void validate(String name, Double minValue, Double maxValue, String unit) {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("Название нормы обязательно");
        }
        if (unit == null || unit.isBlank()) {
            throw new IllegalArgumentException("Единица измерения обязательна");
        }
        if (minValue == null || maxValue == null || !Double.isFinite(minValue) || !Double.isFinite(maxValue)) {
            throw new IllegalArgumentException("Границы нормы должны быть числами");
        }
        if (maxValue < minValue) {
            throw new IllegalArgumentException("Максимум не может быть меньше минимума");
        }
    }

    @CacheEvict(value = "norms", allEntries = true)
    public void delete(Long id) {
        if (!normRepository.existsById(id)) {
            throw new IllegalArgumentException("Норма не найдена");
        }
        normRepository.deleteById(id);
    }
}
