package org.example.security;

import org.example.model.enums.Role;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * Доступ к данным аутентифицированного пользователя из SecurityContext.
 * Единственная точка, через которую сервисы и контроллеры узнают,
 * кто выполняет запрос и какие у него роли.
 */
public final class CurrentUserContext {

    private CurrentUserContext() {
    }

    public static Long currentUserId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && auth.getPrincipal() instanceof Long) {
            return (Long) auth.getPrincipal();
        }
        return null;
    }

    public static boolean hasRole(Role role) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getAuthorities() == null) return false;
        String need = "ROLE_" + role.name();
        return auth.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .anyMatch(need::equals);
    }

    public static boolean isAdmin() {
        return hasRole(Role.ADMIN);
    }

    public static boolean isDoctorOrAdmin() {
        return hasRole(Role.DOCTOR) || hasRole(Role.ADMIN);
    }

    public static boolean isPatient() {
        return hasRole(Role.PATIENT);
    }
}
