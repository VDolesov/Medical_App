package org.example.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class PatientDirectoryEntryDto {

    public long id;
    public String code;
    public int age;
    public String gender;
    @JsonProperty("has_app_account")
    public boolean hasAppAccount;
    @JsonProperty("attending_doctor_user_id")
    public Long attendingDoctorUserId;
    @JsonProperty("attending_doctor_label")
    public String attendingDoctorLabel;
    @JsonProperty("viewer_status")
    public String viewerStatus;
    @JsonProperty("lk_user_name")
    public String lkUserName;

    public PatientDirectoryEntryDto(long id, String code, int age, String gender, boolean hasAppAccount,
                                    Long attendingDoctorUserId, String attendingDoctorLabel, String viewerStatus,
                                    String lkUserName) {
        this.id = id;
        this.code = code;
        this.age = age;
        this.gender = gender;
        this.hasAppAccount = hasAppAccount;
        this.attendingDoctorUserId = attendingDoctorUserId;
        this.attendingDoctorLabel = attendingDoctorLabel;
        this.viewerStatus = viewerStatus;
        this.lkUserName = lkUserName;
    }
}
