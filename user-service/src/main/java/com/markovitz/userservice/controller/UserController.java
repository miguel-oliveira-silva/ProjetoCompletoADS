package com.markovitz.userservice.controller;

import com.markovitz.userservice.dto.RegisterRequestDTO;
import com.markovitz.userservice.dto.UserResponseDTO;
import com.markovitz.userservice.entity.User;
import com.markovitz.userservice.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

// Controller REST - mapeia requisições HTTP para métodos Java
@RestController
@RequestMapping("/api/users")
@Tag(name = "Usuários", description = "Cadastro e gestão de investidores")
public class UserController {

    private static final Logger log = LoggerFactory.getLogger(UserController.class);
    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    // POST /api/users/register - Cria novo usuário e publica evento no RabbitMQ
    @Operation(summary = "Registrar novo usuário", description = "Cria um novo investidor e publica evento 'user.registered' no RabbitMQ")
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "Usuário criado com sucesso"),
        @ApiResponse(responseCode = "400", description = "Dados inválidos (validação falhou)"),
        @ApiResponse(responseCode = "409", description = "E-mail já cadastrado")
    })
    @PostMapping("/register")
    public ResponseEntity<UserResponseDTO> register(
            @Valid @RequestBody RegisterRequestDTO requestDTO) {

        log.info("Requisição de registro recebida para: {}", requestDTO.getEmail());
        UserResponseDTO response = userService.register(requestDTO);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    // GET /api/users/{id} - Busca usuário por ID
    @Operation(summary = "Buscar usuário por ID")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Usuário encontrado"),
        @ApiResponse(responseCode = "404", description = "Usuário não encontrado")
    })
    @GetMapping("/{id}")
    public ResponseEntity<UserResponseDTO> findById(
            @Parameter(description = "ID do usuário") @PathVariable Long id) {

        log.debug("Requisição para buscar usuário ID: {}", id);
        UserResponseDTO response = userService.findById(id);
        return ResponseEntity.ok(response);
    }

    // GET /api/users - Lista todos os usuários
    @Operation(summary = "Listar todos os usuários")
    @GetMapping
    public ResponseEntity<List<UserResponseDTO>> findAll() {

        log.debug("Requisição para listar todos os usuários");
        List<UserResponseDTO> users = userService.findAll();
        return ResponseEntity.ok(users);
    }

    // PUT /api/users/{id}/risk-profile - Atualiza perfil de risco
    @Operation(summary = "Atualizar perfil de risco", description = "Valores aceitos: CONSERVADOR, MODERADO, AGRESSIVO")
    @ApiResponse(responseCode = "200", description = "Perfil atualizado")
    @PutMapping("/{id}/risk-profile")
    public ResponseEntity<UserResponseDTO> updateRiskProfile(
            @Parameter(description = "ID do usuário") @PathVariable Long id,
            @RequestBody User.RiskProfile riskProfile) {

        log.info("Requisição para atualizar perfil de risco do usuário {} para {}", id, riskProfile);
        UserResponseDTO response = userService.updateRiskProfile(id, riskProfile);
        return ResponseEntity.ok(response);
    }
}
