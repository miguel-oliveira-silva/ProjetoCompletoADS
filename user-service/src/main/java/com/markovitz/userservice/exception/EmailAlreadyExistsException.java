package com.markovitz.userservice.exception;

// Exceção lançada quando email já existe (retorna HTTP 409 Conflict)
public class EmailAlreadyExistsException extends RuntimeException {

    public EmailAlreadyExistsException(String message) {
        super(message);
    }
}
