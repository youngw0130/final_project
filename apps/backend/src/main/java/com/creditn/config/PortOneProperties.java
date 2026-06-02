package com.creditn.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "portone")
@Getter
@Setter
public class PortOneProperties {
    private String storeId;
    private String apiSecret;
    private String channelKey;
    private String webhookSecret;
    private String baseUrl = "https://api.portone.io";
}
