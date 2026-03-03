package com.jholjhal.push.controller;

import com.google.firebase.messaging.FirebaseMessagingException;
import com.jholjhal.push.dto.ApiResponse;
import com.jholjhal.push.dto.RegisterTokenRequest;
import com.jholjhal.push.dto.SendMessagePushRequest;
import com.jholjhal.push.dto.UnregisterTokenRequest;
import com.jholjhal.push.service.FcmPushService;
import com.jholjhal.push.service.TokenRegistryService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@Validated
@RequestMapping("/api/push")
public class PushNotificationController {

    private static final Logger log = LoggerFactory.getLogger(PushNotificationController.class);
    private final TokenRegistryService tokenRegistryService;
    private final FcmPushService fcmPushService;

    public PushNotificationController(TokenRegistryService tokenRegistryService, FcmPushService fcmPushService) {
        this.tokenRegistryService = tokenRegistryService;
        this.fcmPushService = fcmPushService;
    }

    @PostMapping("/tokens/register")
    public ResponseEntity<ApiResponse> registerToken(@Valid @RequestBody RegisterTokenRequest request) {
        log.info("API /tokens/register userRef={} platform={}", request.userRef(), request.platform());
        tokenRegistryService.registerToken(request.userRef().trim(), request.token().trim());
        return ResponseEntity.ok(ApiResponse.ok("Token registered"));
    }

    @PostMapping("/tokens/unregister")
    public ResponseEntity<ApiResponse> unregisterToken(@Valid @RequestBody UnregisterTokenRequest request) {
        log.info("API /tokens/unregister userRef={}", request.userRef());
        tokenRegistryService.unregisterToken(request.userRef().trim(), request.token().trim());
        return ResponseEntity.ok(ApiResponse.ok("Token unregistered"));
    }

    @PostMapping("/messages/send")
    public ResponseEntity<ApiResponse> sendMessagePush(@Valid @RequestBody SendMessagePushRequest request)
            throws FirebaseMessagingException {
        log.info("API /messages/send recipientRef={} senderRef={} conversationId={} messageId={}",
                request.recipientRef(), request.senderRef(), request.conversationId(), request.messageId());
        int successCount = fcmPushService.sendMessagePush(request);
        return ResponseEntity.ok(ApiResponse.ok("Push sent. Success count: " + successCount));
    }

    @PostMapping("/test/send-to-token")
    public ResponseEntity<ApiResponse> sendToSingleToken(
            @RequestParam @NotBlank String token,
            @RequestParam(defaultValue = "Test notification") String title,
            @RequestParam(defaultValue = "Hello from Spring Boot") String body
    ) throws FirebaseMessagingException {
        String messageId = fcmPushService.sendSingleTokenTest(token.trim(), title.trim(), body.trim());
        return ResponseEntity.ok(ApiResponse.ok("Message id: " + messageId));
    }

    @GetMapping("/tokens")
    public ResponseEntity<Map<String, Integer>> countTokens(@RequestParam @NotBlank String userRef) {
        int count = tokenRegistryService.getTokens(userRef.trim()).size();
        return ResponseEntity.ok(Map.of("count", count));
    }

    @GetMapping("/debug/registry")
    public ResponseEntity<Map<String, Object>> debugRegistry() {
        Map<String, Integer> perUser = tokenRegistryService.snapshotUserTokenCounts();
        return ResponseEntity.ok(Map.of(
                "totalUsers", perUser.size(),
                "totalTokens", tokenRegistryService.totalTokenCount(),
                "perUserCounts", perUser
        ));
    }
}
