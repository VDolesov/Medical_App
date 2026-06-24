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
        AnalysisNorm n = new AnalysisNorm();
        n.setName(name);
        n.setMinValue(minValue);
        n.setMaxValue(maxValue);
        n.setUnit(unit);
        return normRepository.save(n);
    }

    @CacheEvict(value = "norms", allEntries = true)
    public AnalysisNorm update(Long id, String name, Double minValue, Double maxValue, String unit) {
        AnalysisNorm n = normRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Норма не найдена"));
        n.setName(name);
        n.setMinValue(minValue);
        n.setMaxValue(maxValue);
        n.setUnit(unit);
        return normRepository.save(n);
    }

    @CacheEvict(value = "norms", allEntries = true)
    public void delete(Long id) {
        if (!normRepository.existsById(id)) {
            throw new IllegalArgumentException("Норма не найдена");
        }
        normRepository.deleteById(id);
    }
}
