package com.creditn.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SignupRequest(
        @NotBlank @Size(min = 2, max = 50) String username,
        @NotBlank @Email String email,
        @NotBlank @Size(min = 6) String password,
        String phoneNumber
) {}
