package com.markovitz.userservice.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Configuração do RabbitMQ para mensageria assíncrona.
 * Define o exchange, queues e bindings para comunicação entre microsserviços.
 */
@Configuration
public class RabbitMQConfig {

    // Constantes para evitar typos nas routing keys
    public static final String EXCHANGE_NAME = "markovitz.exchange";
    public static final String USER_REGISTERED_QUEUE = "user.registered.queue";
    public static final String USER_REGISTERED_ROUTING_KEY = "user.registered";

    // Exchange do tipo Topic - permite wildcards nas routing keys (ex: user.*)
    @Bean
    public TopicExchange markovitzExchange() {
        return new TopicExchange(EXCHANGE_NAME, true, false);
    }

    // Fila durável para eventos de usuário registrado
    @Bean
    public Queue userRegisteredQueue() {
        return QueueBuilder
                .durable(USER_REGISTERED_QUEUE)
                .build();
    }

    // Liga o exchange à fila usando a routing key
    @Bean
    public Binding userRegisteredBinding(Queue userRegisteredQueue,
                                         TopicExchange markovitzExchange) {
        return BindingBuilder
                .bind(userRegisteredQueue)
                .to(markovitzExchange)
                .with(USER_REGISTERED_ROUTING_KEY);
    }

    // Conversor JSON para serializar/desserializar eventos
    @Bean
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    // Template para publicar mensagens no RabbitMQ
    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory) {
        RabbitTemplate template = new RabbitTemplate(connectionFactory);
        template.setMessageConverter(jsonMessageConverter());
        return template;
    }
}
