package com.markovitz.userservice.repository;

import com.markovitz.userservice.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

// Repository para acesso aos dados de User
// Spring Data JPA gera automaticamente a implementação dos métodos
@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    // Busca usuário por email - retorna Optional para evitar NullPointerException
    Optional<User> findByEmail(String email);

    // Verifica se email já existe (mais eficiente que findByEmail quando só precisa checar existência)
    boolean existsByEmail(String email);
}
