package org.example.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.config.OpenApiConfig;
import org.example.service.UploadService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;
import java.util.Set;

@RestController
@Tag(name = OpenApiConfig.TAG_UPLOAD)
public class UploadController {

    private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/octet-stream",
            "application/zip"
    );

    private final UploadService uploadService;
    private final long maxUploadSizeBytes;

    public UploadController(UploadService uploadService,
                            @Value("${app.upload.max-size-bytes:10485760}") long maxUploadSizeBytes) {
        this.uploadService = uploadService;
        this.maxUploadSizeBytes = maxUploadSizeBytes;
    }

    @PostMapping("/upload")
    @Operation(
            summary = "Загрузить XLSX с анализами",
            description = """
                    Принимает Excel-файл с результатами лабораторных анализов и возвращает
                    разобранный отчёт с отклонениями от референсных диапазонов.

                    Требования к файлу:
                    - формат `.xlsx`, размер до 10 МБ;
                    - обязательные столбцы: «Код пациента», «Возраст»;
                    - дополнительно поддерживаются TNM-стадии, Bethesda, тип операции и др.

                    Доступно только врачу и администратору. Возвращает `reportId` для последующего просмотра.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Файл успешно обработан"),
            @ApiResponse(responseCode = "400", description = "Файл пустой, слишком большой или некорректного формата"),
            @ApiResponse(responseCode = "403", description = "Роль PATIENT — загрузка запрещена"),
            @ApiResponse(responseCode = "429", description = "Превышен лимит загрузок с одного IP")
    })
    public ResponseEntity<?> upload(@RequestParam("file") MultipartFile file) throws IOException {
        if (!MeController.isDoctorOrAdmin()) {
            return ResponseEntity.status(403).body(Map.of("error", "Нет прав на загрузку"));
        }
        if (file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Файл не выбран"));
        }
        if (file.getSize() > maxUploadSizeBytes) {
            return ResponseEntity.badRequest().body(Map.of("error", "File is too large"));
        }
        if (!hasXlsxExtension(file.getOriginalFilename())) {
            return ResponseEntity.badRequest().body(Map.of("error", "Only .xlsx files are allowed"));
        }
        String contentType = file.getContentType();
        if (contentType != null && !contentType.isBlank() && !ALLOWED_CONTENT_TYPES.contains(contentType)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Unsupported file type"));
        }
        Map<String, Object> result = uploadService.processUpload(MeController.currentUserId(), file.getOriginalFilename(), file);
        return ResponseEntity.ok(result);
    }

    private static boolean hasXlsxExtension(String fileName) {
        return fileName != null && fileName.trim().toLowerCase().endsWith(".xlsx");
    }
}
