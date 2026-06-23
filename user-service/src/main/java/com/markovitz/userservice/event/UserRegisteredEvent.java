package com.markovitz.userservice.event;

import com.markovitz.userservice.entity.User;
import java.time.LocalDateTime;

/**
 * Evento publicado quando um usuário se registra.
 * Consumido pelo notification-service via RabbitMQ.
 */
public class UserRegisteredEvent {

    private Long userId;
    private String userName;
    private String userEmail;
    private User.RiskProfile riskProfile;
    private LocalDateTime occurredAt;

    // Construtor vazio necessário para o Jackson
    public UserRegisteredEvent() {}

    public UserRegisteredEvent(Long userId, String userName, String userEmail,
                               User.RiskProfile riskProfile, LocalDateTime occurredAt) {
        this.userId = userId;
        this.userName = userName;
        this.userEmail = userEmail;
        this.riskProfile = riskProfile;
        this.occurredAt = occurredAt;
    }

    // Factory method para criar a partir da entidade User
    public static UserRegisteredEvent from(User user) {
        return new UserRegisteredEvent(
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getRiskProfile(),
                LocalDateTime.now()
        );
    }

    /** Perfil de risco — o notification-service pode incluir dicas na boas-vindas */
    private User.RiskProfile riskProfile;

    /**
     * Momento em que o evento ocorreu.
     *
     * BOAS PRÁTICAS:
     * Sempre inclua um timestamp no evento para:
     *   - Rastreabilidade (quando exatamente aconteceu?)
     *   - Ordenação temporal de eventos
     *   - Detecção de eventos duplicados (idempotência)
     */
    private LocalDateTime occurredAt;

    // =========================================================================
    // CONSTRUTORES
    // =========================================================================

    /** Construtor padrão — obrigatório para o Jackson desserializar */
    public UserRegisteredEvent() {}

    /** Construtor completo */
    public UserRegisteredEvent(Long userId, String userName, String userEmail,
                               User.RiskProfile riskProfile, LocalDateTime occurredAt) {
        this.userId = userId;
        this.userName = userName;
        this.userEmail = userEmail;
        this.riskProfile = riskProfile;
        this.occurredAt = occurredAt;
    }

    // =========================================================================
    // MÉTODO DE FÁBRICA
    // =========================================================================

    /**
     * Método de fábrica para criar o evento a partir da entidade User.
     * Isso evita que o Service precise conhecer os detalhes internos do evento.
     *
     * @param user o usuário recém-cadastrado
     * @return evento pronto para ser publicado no RabbitMQ
     */
    public static UserRegisteredEvent from(User user) {
        return new UserRegisteredEvent(
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getRiskProfile(),
                LocalDateTime.now() // momento exato do evento
        );
    }

    // =========================================================================
    // Getters e Setters
    // =========================================================================

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public String getUserName() { return userName; }
    public void setUserName(String userName) { this.userName = userName; }

    public String getUserEmail() { return userEmail; }
    public void setUserEmail(String userEmail) { this.userEmail = userEmail; }

    public User.RiskProfile getRiskProfile() { return riskProfile; }
    public void setRiskProfile(User.RiskProfile riskProfile) { this.riskProfile = riskProfile; }

    public LocalDateTime getOccurredAt() { return occurredAt; }
    public void setOccurredAt(LocalDateTime occurredAt) { this.occurredAt = occurredAt; }

    @Override
    public String toString() {
        return "UserRegisteredEvent{userId=" + userId +
                ", userName='" + userName + '\'' +
                ", userEmail='" + userEmail + '\'' +
                ", riskProfile=" + riskProfile +
                ", occurredAt=" + occurredAt + '}';
    }
}
