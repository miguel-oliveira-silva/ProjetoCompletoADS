package com.markovitz.userservice.exception;

// Exceção lançada quando usuário não é encontrado (retorna HTTP 404)
public class UserNotFoundException extends RuntimeException {

    public UserNotFoundException(String message) {
        super(message);
    }
}
