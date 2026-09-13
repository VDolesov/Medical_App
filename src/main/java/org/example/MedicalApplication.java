package org.example;

import org.example.config.DatabaseUrl;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration;
import org.springframework.cache.annotation.EnableCaching;

@EnableCaching
@SpringBootApplication(exclude = UserDetailsServiceAutoConfiguration.class)
public class MedicalApplication {

    public static void main(String[] args) {
        // Render/Neon/Railway дают одну строку DATABASE_URL — раскладываем её в spring.datasource.*
        DatabaseUrl.applyToSystemProperties(System.getenv("DATABASE_URL"));
        SpringApplication.run(MedicalApplication.class, args);
    }
}
