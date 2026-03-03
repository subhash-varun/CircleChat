package com.jholjhal.push.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record RegisterTokenRequest(
        @NotBlank String userRef,
        @NotBlank String token,
        @Pattern(regexp = "android|ios|web", message = "platform must be android, ios, or web")
        String platform
) {
}
