package com.markovitz.userservice.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Configuração do Swagger para documentação automática da API.
 * 
 * O Springdoc lê os controllers e gera a doc automaticamente,
 * aqui só personalizamos o título e descrição que aparece no Swagger UI.
 * 
 * Para acessar: http://localhost:8081/swagger-ui.html
 */
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI userServiceOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("User Service API")
                        .description(
                                "Microsserviço de gestão de usuários do Sistema Markovitz.\n\n" +
                                "Responsável por:\n" +
                                "- Cadastro e autenticação de investidores\n" +
                                "- Gerenciamento do perfil de risco (CONSERVADOR, MODERADO, AGRESSIVO)\n" +
                                "- Publicação de eventos via RabbitMQ ao registrar novos usuários"
                        )
                        .version("1.0.0")
                        .contact(new Contact()
                                .name("Equipe Markovitz")
                                .email("markovitz@ads.edu.br")
                        )
                );
    }
}
