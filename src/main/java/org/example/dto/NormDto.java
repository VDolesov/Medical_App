package org.example.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import org.example.model.AnalysisNorm;

public class NormDto {
    private Long id;
    private String name;
    @JsonProperty("min_value")
    private Double minValue;
    @JsonProperty("max_value")
    private Double maxValue;
    private String unit;

    public static NormDto from(AnalysisNorm n) {
        NormDto dto = new NormDto();
        dto.id = n.getId();
        dto.name = n.getName();
        dto.minValue = n.getMinValue();
        dto.maxValue = n.getMaxValue();
        dto.unit = n.getUnit();
        return dto;
    }

    public Long getId() { return id; }
    public String getName() { return name; }
    public Double getMinValue() { return minValue; }
    public Double getMaxValue() { return maxValue; }
    public String getUnit() { return unit; }
}
