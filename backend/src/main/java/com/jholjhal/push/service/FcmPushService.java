package com.jholjhal.push.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.SendResponse;
import com.jholjhal.push.dto.SendMessagePushRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
public class FcmPushService {

    private static final Logger log = LoggerFactory.getLogger(FcmPushService.class);

    private static final Set<MessagingErrorCode> INVALID_TOKEN_ERRORS = Set.of(
            MessagingErrorCode.UNREGISTERED,
            MessagingErrorCode.INVALID_ARGUMENT
    );

    private final FirebaseMessaging firebaseMessaging;
    private final TokenRegistryService tokenRegistryService;

    public FcmPushService(FirebaseMessaging firebaseMessaging, TokenRegistryService tokenRegistryService) {
        this.firebaseMessaging = firebaseMessaging;
        this.tokenRegistryService = tokenRegistryService;
    }

    public int sendMessagePush(SendMessagePushRequest request) throws FirebaseMessagingException {
        Set<String> tokens = tokenRegistryService.getTokens(request.recipientRef());
        log.debug("Push request received. recipientRef={}, senderRef={}, conversationId={}, messageId={}, tokenCount={}",
                request.recipientRef(), request.senderRef(), request.conversationId(), request.messageId(), tokens.size());
        if (tokens.isEmpty()) {
            log.warn("No tokens for recipientRef={}, push skipped.", request.recipientRef());
            return 0;
        }

        List<String> tokenList = new ArrayList<>(tokens);
        Map<String, String> dataPayload = new HashMap<>();
        dataPayload.put("type", "chat_message");
        dataPayload.put("conversation_id", request.conversationId());
        dataPayload.put("message_id", request.messageId());
        dataPayload.put("sender_ref", request.senderRef());
        if (request.data() != null) {
            dataPayload.putAll(request.data());
        }

        MulticastMessage multicastMessage = MulticastMessage.builder()
                .addAllTokens(tokenList)
                .setNotification(Notification.builder()
                        .setTitle(request.title())
                        .setBody(request.body())
                        .build())
                .putAllData(dataPayload)
                .build();

        var batchResponse = firebaseMessaging.sendEachForMulticast(multicastMessage);
        cleanupInvalidTokens(request.recipientRef(), tokenList, batchResponse.getResponses());
        log.info("Push send completed. recipientRef={}, successCount={}, failureCount={}",
                request.recipientRef(), batchResponse.getSuccessCount(), batchResponse.getFailureCount());
        return batchResponse.getSuccessCount();
    }

    private void cleanupInvalidTokens(String userRef, List<String> tokens, List<SendResponse> responses) {
        for (int i = 0; i < responses.size(); i++) {
            SendResponse response = responses.get(i);
            if (response.isSuccessful() || response.getException() == null) {
                continue;
            }
            log.warn("Push token send failed. userRef={}, tokenSuffix={}, errorCode={}, message={}",
                    userRef,
                    lastN(tokens.get(i), 8),
                    response.getException().getMessagingErrorCode(),
                    response.getException().getMessage());
            if (isInvalidTokenError(response.getException())) {
                tokenRegistryService.unregisterToken(userRef, tokens.get(i));
                log.warn("Invalid token removed. userRef={}, tokenSuffix={}", userRef, lastN(tokens.get(i), 8));
            }
        }
    }

    private boolean isInvalidTokenError(FirebaseMessagingException e) {
        MessagingErrorCode errorCode = e.getMessagingErrorCode();
        return errorCode != null && INVALID_TOKEN_ERRORS.contains(errorCode);
    }

    public String sendSingleTokenTest(String token, String title, String body) throws FirebaseMessagingException {
        Message message = Message.builder()
                .setToken(token)
                .setNotification(Notification.builder().setTitle(title).setBody(body).build())
                .build();
        String messageId = firebaseMessaging.send(message);
        log.info("Single token test sent. tokenSuffix={}, messageId={}", lastN(token, 8), messageId);
        return messageId;
    }

    private String lastN(String value, int n) {
        if (value == null || value.isEmpty()) return "";
        int start = Math.max(0, value.length() - n);
        return value.substring(start);
    }
}
