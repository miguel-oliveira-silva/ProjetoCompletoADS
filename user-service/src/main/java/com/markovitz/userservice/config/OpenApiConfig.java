package com.markovitz.userservice.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Configuração do Swagger/OpenAPI para documentação da API.
 * Acesse: http://localhost:8081/swagger-ui.html
 */
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI userServiceOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("User Service API")
                        .description("Microsserviço de gestão de usuários e perfis de risco")
                        .version("1.0.0")
                        .contact(new Contact()
                                .name("Equipe FORMA")
                                .email("migsos01120@gmail.com")
                        )
                );
    }
}
