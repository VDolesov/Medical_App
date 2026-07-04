package org.example.model;

import jakarta.persistence.*;

@Entity
@Table(name = "analysis_norms")
public class AnalysisNorm {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(name = "min_value", nullable = false)
    private Double minValue;

    @Column(name = "max_value", nullable = false)
    private Double maxValue;

    @Column(nullable = false)
    private String unit;

    public Long getId() { return id; }
    public String getName() { return name; }
    public Double getMinValue() { return minValue; }
    public Double getMaxValue() { return maxValue; }
    public String getUnit() { return unit; }

    public void setId(Long id) { this.id = id; }
    public void setName(String name) { this.name = name; }
    public void setMinValue(Double minValue) { this.minValue = minValue; }
    public void setMaxValue(Double maxValue) { this.maxValue = maxValue; }
    public void setUnit(String unit) { this.unit = unit; }
}
