package com.jholjhal.push.dto;

import jakarta.validation.constraints.NotBlank;

public record UnregisterTokenRequest(
        @NotBlank String userRef,
        @NotBlank String token
) {
}
