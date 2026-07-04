package org.example.service;

import org.example.model.AnalysisNorm;
import org.example.repository.AnalysisNormRepository;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class NormsServiceTest {

    private final AnalysisNormRepository repository = mock(AnalysisNormRepository.class);
    private final NormsService service = new NormsService(repository);

    @Test
    void rejectsMaxBelowMin() {
        assertThatThrownBy(() -> service.create("ТТГ", 5.0, 1.0, "мМЕ/л"))
                .isInstanceOf(IllegalArgumentException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void rejectsBlankName() {
        assertThatThrownBy(() -> service.create("   ", 1.0, 5.0, "мМЕ/л"))
                .isInstanceOf(IllegalArgumentException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void rejectsMissingBounds() {
        assertThatThrownBy(() -> service.create("ТТГ", null, 5.0, "мМЕ/л"))
                .isInstanceOf(IllegalArgumentException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void savesValidNormAndTrims() {
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        AnalysisNorm saved = service.create("  ТТГ  ", 0.4, 4.0, " мМЕ/л ");
        assertThat(saved.getName()).isEqualTo("ТТГ");
        assertThat(saved.getUnit()).isEqualTo("мМЕ/л");
        assertThat(saved.getMinValue()).isEqualTo(0.4);
        assertThat(saved.getMaxValue()).isEqualTo(4.0);
        verify(repository).save(any());
    }
}
