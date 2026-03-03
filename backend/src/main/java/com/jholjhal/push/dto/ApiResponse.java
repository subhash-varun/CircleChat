package com.jholjhal.push.dto;

public record ApiResponse(
        boolean success,
        String message
) {
    public static ApiResponse ok(String message) {
        return new ApiResponse(true, message);
    }

    public static ApiResponse error(String message) {
        return new ApiResponse(false, message);
    }
}
