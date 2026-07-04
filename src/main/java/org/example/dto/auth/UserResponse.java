package org.example.dto.auth;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

public class UserResponse {

    private Long id;
    private String username;
    @JsonProperty("first_name")
    private String firstName;
    @JsonProperty("last_name")
    private String lastName;
    private String role;
    private String email;
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @JsonProperty("patient_id")
    private Long patientId;
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @JsonProperty("patient_code")
    private String patientCode;

    public UserResponse() {}

    public UserResponse(Long id, String username, String firstName, String lastName, String role, String email) {
        this(id, username, firstName, lastName, role, email, null, null);
    }

    public UserResponse(Long id, String username, String firstName, String lastName, String role, String email, Long patientId) {
        this(id, username, firstName, lastName, role, email, patientId, null);
    }

    public UserResponse(Long id, String username, String firstName, String lastName, String role, String email,
                        Long patientId, String patientCode) {
        this.id = id;
        this.username = username;
        this.firstName = firstName;
        this.lastName = lastName;
        this.role = role;
        this.email = email != null ? email : "";
        this.patientId = patientId;
        this.patientCode = patientCode;
    }

    public Long getId() { return id; }
    public String getUsername() { return username; }
    public String getFirstName() { return firstName; }
    public String getLastName() { return lastName; }
    public String getRole() { return role; }
    public String getEmail() { return email; }
    public Long getPatientId() { return patientId; }
    public String getPatientCode() { return patientCode; }

    public void setId(Long id) { this.id = id; }
    public void setUsername(String username) { this.username = username; }
    public void setFirstName(String firstName) { this.firstName = firstName; }
    public void setLastName(String lastName) { this.lastName = lastName; }
    public void setRole(String role) { this.role = role; }
    public void setEmail(String email) { this.email = email; }
    public void setPatientId(Long patientId) { this.patientId = patientId; }
    public void setPatientCode(String patientCode) { this.patientCode = patientCode; }
}
