package com.creditn.portone;

public class PortOneApiException extends RuntimeException {

    private final int statusCode;

    public PortOneApiException(String message) {
        super(message);
        this.statusCode = 500;
    }

    public PortOneApiException(String message, int statusCode) {
        super(message);
        this.statusCode = statusCode;
    }

    public int getStatusCode() {
        return statusCode;
    }
}
