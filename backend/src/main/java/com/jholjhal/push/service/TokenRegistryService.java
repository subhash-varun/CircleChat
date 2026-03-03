package com.jholjhal.push.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Collections;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class TokenRegistryService {

    private static final Logger log = LoggerFactory.getLogger(TokenRegistryService.class);
    private final ConcurrentHashMap<String, Set<String>> tokensByUser = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, String> ownerByToken = new ConcurrentHashMap<>();

    public synchronized void registerToken(String userRef, String token) {
        String previousOwner = ownerByToken.get(token);
        if (previousOwner != null && !previousOwner.equals(userRef)) {
            removeTokenFromUser(previousOwner, token);
            log.info("Token ownership transferred. tokenSuffix={}, fromUserRef={}, toUserRef={}",
                    lastN(token, 8), previousOwner, userRef);
        }

        Set<String> set = tokensByUser.computeIfAbsent(userRef, ignored -> ConcurrentHashMap.newKeySet());
        set.add(token);
        ownerByToken.put(token, userRef);
        log.debug("Token registered. userRef={}, userTokenCount={}, totalUsers={}, totalTokens={}",
                userRef, set.size(), tokensByUser.size(), ownerByToken.size());
    }

    public synchronized void unregisterToken(String userRef, String token) {
        Set<String> userTokens = tokensByUser.get(userRef);
        if (userTokens == null) {
            log.debug("Unregister ignored. No tokens found for userRef={}", userRef);
            return;
        }
        removeTokenFromUser(userRef, token);
        int remaining = tokensByUser.getOrDefault(userRef, Collections.emptySet()).size();
        log.debug("Token unregistered. userRef={}, remainingUserTokens={}, totalUsers={}, totalTokens={}",
                userRef, remaining, tokensByUser.size(), ownerByToken.size());
    }

    public Set<String> getTokens(String userRef) {
        return tokensByUser.getOrDefault(userRef, Collections.emptySet());
    }

    public Map<String, Integer> snapshotUserTokenCounts() {
        Map<String, Integer> snapshot = new HashMap<>();
        tokensByUser.forEach((user, set) -> snapshot.put(user, set.size()));
        return snapshot;
    }

    public int totalTokenCount() {
        return ownerByToken.size();
    }

    private void removeTokenFromUser(String userRef, String token) {
        Set<String> userTokens = tokensByUser.get(userRef);
        if (userTokens == null) return;
        userTokens.remove(token);
        ownerByToken.remove(token, userRef);
        if (userTokens.isEmpty()) {
            tokensByUser.remove(userRef);
        }
    }

    private String lastN(String value, int n) {
        if (value == null || value.isEmpty()) return "";
        int start = Math.max(0, value.length() - n);
        return value.substring(start);
    }
}
