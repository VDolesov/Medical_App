package org.example.dto.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class RegisterRequest {

    @NotBlank
    @Size(min = 3, max = 64)
    private String username;

    @NotBlank
    @Size(min = 10, max = 128)
    private String password;

    @Email
    @NotBlank
    @Size(max = 255)
    private String email;

    @NotBlank
    @Size(max = 100)
    private String firstName;

    @NotBlank
    @Size(max = 100)
    private String lastName;

    @NotBlank
    @Size(max = 20)
    private String role;

    @Size(max = 128)
    private String adminSecret;

    @Size(max = 100)
    private String patientCode;
    private Integer patientAge;

    public String getUsername() { return username; }
    public String getPassword() { return password; }
    public String getEmail() { return email; }
    public String getFirstName() { return firstName; }
    public String getLastName() { return lastName; }
    public String getRole() { return role; }
    public String getAdminSecret() { return adminSecret; }
    public String getPatientCode() { return patientCode; }
    public Integer getPatientAge() { return patientAge; }

    public void setUsername(String username) { this.username = username; }
    public void setPassword(String password) { this.password = password; }
    public void setEmail(String email) { this.email = email; }
    public void setFirstName(String firstName) { this.firstName = firstName; }
    public void setLastName(String lastName) { this.lastName = lastName; }
    public void setRole(String role) { this.role = role; }
    public void setAdminSecret(String adminSecret) { this.adminSecret = adminSecret; }
    public void setPatientCode(String patientCode) { this.patientCode = patientCode; }
    public void setPatientAge(Integer patientAge) { this.patientAge = patientAge; }
}
