package com.jholjhal.push.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

@Configuration
@EnableConfigurationProperties(FirebaseProperties.class)
public class FirebaseConfig {

    @Bean
    public FirebaseApp firebaseApp(FirebaseProperties props) throws IOException {
        if (FirebaseApp.getApps().isEmpty()) {
            FirebaseOptions.Builder builder = FirebaseOptions.builder()
                    .setCredentials(resolveCredentials(props));

            if (StringUtils.hasText(props.projectId())) {
                builder.setProjectId(props.projectId());
            }

            return FirebaseApp.initializeApp(builder.build());
        }
        return FirebaseApp.getInstance();
    }

    @Bean
    public FirebaseMessaging firebaseMessaging(FirebaseApp firebaseApp) {
        return FirebaseMessaging.getInstance(firebaseApp);
    }

    private GoogleCredentials resolveCredentials(FirebaseProperties props) throws IOException {
        String credentialsPath = resolveCredentialsPath(props);
        if (StringUtils.hasText(credentialsPath)) {
            InputStream credentialsStream = new FileInputStream(credentialsPath);
            return GoogleCredentials.fromStream(credentialsStream);
        }
        return GoogleCredentials.getApplicationDefault();
    }

    private String resolveCredentialsPath(FirebaseProperties props) {
        if (StringUtils.hasText(props.serviceAccountPath())) {
            return props.serviceAccountPath();
        }
        String firebasePath = System.getenv("FIREBASE_SERVICE_ACCOUNT_PATH");
        if (StringUtils.hasText(firebasePath)) return firebasePath;
        String adcPath = System.getenv("GOOGLE_APPLICATION_CREDENTIALS");
        if (StringUtils.hasText(adcPath)) return adcPath;
        return null;
    }
}
