package org.example.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;
import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
public class RateLimitFilter extends OncePerRequestFilter {

    private static final Map<String, Bucket> BUCKETS = new ConcurrentHashMap<>();
    private static final AtomicInteger REQUESTS_SINCE_CLEANUP = new AtomicInteger();

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        Limit limit = limitFor(request);
        if (limit == null) {
            filterChain.doFilter(request, response);
            return;
        }

        long now = System.currentTimeMillis();
        if (REQUESTS_SINCE_CLEANUP.incrementAndGet() > 1000) {
            REQUESTS_SINCE_CLEANUP.set(0);
            cleanup(now);
        }

        String ip = clientIp(request);
        String key = request.getMethod() + " " + request.getRequestURI() + " " + ip;
        long windowMs = limit.window().toMillis();
        boolean allowed;
        synchronized (BUCKETS) {
            Bucket bucket = BUCKETS.get(key);
            if (bucket == null || now - bucket.windowStartMillis > windowMs) {
                BUCKETS.put(key, new Bucket(now, 1));
                allowed = true;
            } else if (bucket.count < limit.maxRequests()) {
                bucket.count++;
                allowed = true;
            } else {
                allowed = false;
            }
        }

        if (!allowed) {
            response.setStatus(429);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write("{\"error\":\"Слишком много запросов. Попробуйте позже.\"}");
            return;
        }

        filterChain.doFilter(request, response);
    }

    private static String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            int comma = forwarded.indexOf(',');
            return (comma > 0 ? forwarded.substring(0, comma) : forwarded).trim();
        }
        return request.getRemoteAddr();
    }

    private static Limit limitFor(HttpServletRequest request) {
        if (!"POST".equalsIgnoreCase(request.getMethod())) {
            return null;
        }
        return switch (request.getRequestURI()) {
            case "/login" -> new Limit(10, Duration.ofMinutes(5));
            case "/register" -> new Limit(5, Duration.ofMinutes(15));
            case "/upload" -> new Limit(30, Duration.ofMinutes(15));
            default -> null;
        };
    }

    private static void cleanup(long now) {
        Iterator<Map.Entry<String, Bucket>> it = BUCKETS.entrySet().iterator();
        while (it.hasNext()) {
            Map.Entry<String, Bucket> entry = it.next();
            if (now - entry.getValue().windowStartMillis > Duration.ofMinutes(30).toMillis()) {
                it.remove();
            }
        }
    }

    private static final class Bucket {
        private final long windowStartMillis;
        private int count;

        private Bucket(long windowStartMillis, int count) {
            this.windowStartMillis = windowStartMillis;
            this.count = count;
        }
    }

    private record Limit(int maxRequests, Duration window) {
    }
}
