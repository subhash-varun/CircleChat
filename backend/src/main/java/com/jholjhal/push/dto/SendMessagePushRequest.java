package com.jholjhal.push.dto;

import jakarta.validation.constraints.NotBlank;

import java.util.Map;

public record SendMessagePushRequest(
        @NotBlank String recipientRef,
        @NotBlank String senderRef,
        @NotBlank String conversationId,
        @NotBlank String messageId,
        @NotBlank String title,
        @NotBlank String body,
        Map<String, String> data
) {
}
