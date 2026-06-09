package org.example.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.http.HttpMethod;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.access.AccessDeniedHandler;
import jakarta.servlet.http.HttpServletResponse;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;
    private final boolean publicSwaggerEnabled;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter,
                          @Value("${app.swagger.public-enabled:false}") boolean publicSwaggerEnabled) {
        this.jwtAuthFilter = jwtAuthFilter;
        this.publicSwaggerEnabled = publicSwaggerEnabled;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> {
                    auth.requestMatchers(HttpMethod.OPTIONS, "/**").permitAll();
                    auth.requestMatchers("/register", "/login", "/ping").permitAll();
                    // Health-проба для оркестратора (Railway healthcheck) — без авторизации.
                    // Остальные actuator-эндпоинты остаются закрытыми.
                    auth.requestMatchers("/actuator/health", "/actuator/health/**").permitAll();
                    if (publicSwaggerEnabled) {
                        auth.requestMatchers("/api-docs/**", "/swagger-ui/**", "/v3/api-docs/**").permitAll();
                    }
                    auth.anyRequest().authenticated();
                })
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint(unauthorizedEntryPoint())
                        .accessDeniedHandler(forbiddenAccessDeniedHandler()))
                .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    // Запрос без валидной аутентификации (нет/просрочен/битый JWT) → 401.
    // По умолчанию Spring Security возвращает 403, что путало клиента и не давало
    // ему понять, что нужно перевыпустить токен через /login.
    private AuthenticationEntryPoint unauthorizedEntryPoint() {
        return (request, response, authException) -> {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write("{\"error\":\"Требуется авторизация\"}");
        };
    }

    // Аутентифицирован, но не хватает прав (например, PATIENT на DOCTOR-ручку) → 403.
    private AccessDeniedHandler forbiddenAccessDeniedHandler() {
        return (request, response, accessDeniedException) -> {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write("{\"error\":\"Доступ запрещён\"}");
        };
    }
}
