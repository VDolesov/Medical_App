package org.example.model;

import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "clinical_sources")
public class ClinicalSource {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 64)
    private String code;

    @Column(nullable = false, length = 512)
    private String title;

    @Column(length = 128)
    private String organization;

    private Integer year;

    @Column(length = 1024)
    private String url;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (createdAt == null) createdAt = Instant.now();
    }

    public Long getId() { return id; }
    public String getCode() { return code; }
    public String getTitle() { return title; }
    public String getOrganization() { return organization; }
    public Integer getYear() { return year; }
    public String getUrl() { return url; }
    public String getDescription() { return description; }
    public Instant getCreatedAt() { return createdAt; }

    public void setId(Long id) { this.id = id; }
    public void setCode(String code) { this.code = code; }
    public void setTitle(String title) { this.title = title; }
    public void setOrganization(String organization) { this.organization = organization; }
    public void setYear(Integer year) { this.year = year; }
    public void setUrl(String url) { this.url = url; }
    public void setDescription(String description) { this.description = description; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
