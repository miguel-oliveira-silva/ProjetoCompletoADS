package com.markovitz.assetservice.service;

import com.markovitz.assetservice.config.RabbitMQConfig;
import com.markovitz.assetservice.dto.*;
import com.markovitz.assetservice.entity.Asset;
import com.markovitz.assetservice.entity.AssetPrice;
import com.markovitz.assetservice.event.AssetPriceUpdatedEvent;
import com.markovitz.assetservice.exception.AssetNotFoundException;
import com.markovitz.assetservice.exception.TickerAlreadyExistsException;
import com.markovitz.assetservice.repository.AssetPriceRepository;
import com.markovitz.assetservice.repository.AssetRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

// Service com lógica de negócio e cálculos financeiros (retorno médio μ e volatilidade σ)
@Service
public class AssetService {

    private static final Logger log = LoggerFactory.getLogger(AssetService.class);
    
    // Dias de pregão por ano na B3 (usado para anualizar métricas)
    private static final int TRADING_DAYS_PER_YEAR = 252;

    private final AssetRepository assetRepository;
    private final AssetPriceRepository assetPriceRepository;
    private final RabbitTemplate rabbitTemplate;

    public AssetService(AssetRepository assetRepository,
                        AssetPriceRepository assetPriceRepository,
                        RabbitTemplate rabbitTemplate) {
        this.assetRepository = assetRepository;
        this.assetPriceRepository = assetPriceRepository;
        this.rabbitTemplate = rabbitTemplate;
    }

    // Cadastra novo ativo (ticker normalizado para MAIÚSCULAS)
    @Transactional
    public AssetResponseDTO createAsset(AssetRequestDTO requestDTO) {
        String ticker = requestDTO.getTicker().toUpperCase().trim();
        log.info("Cadastrando novo ativo: {}", ticker);

        if (assetRepository.existsByTicker(ticker)) {
            throw new TickerAlreadyExistsException(
                    "O ativo com ticker '" + ticker + "' já está cadastrado");
        }

        Asset asset = Asset.builder()
                .ticker(ticker)
                .name(requestDTO.getName())
                .sector(requestDTO.getSector())
                .build();

        Asset saved = assetRepository.save(asset);
        log.info("Ativo '{}' cadastrado com ID: {}", ticker, saved.getId());

        return AssetResponseDTO.from(saved, 0);
    }

    // Busca ativo por ticker
    @Transactional(readOnly = true)
    public AssetResponseDTO findByTicker(String ticker) {
        Asset asset = getAssetByTicker(ticker.toUpperCase());
        long count = assetPriceRepository.countByAsset(asset);
        return AssetResponseDTO.from(asset, count);
    }

    // Lista todos os ativos
    @Transactional(readOnly = true)
    public List<AssetResponseDTO> findAll() {
        return assetRepository.findAll()
                .stream()
                .map(asset -> {
                    long count = assetPriceRepository.countByAsset(asset);
                    return AssetResponseDTO.from(asset, count);
                })
                .toList();
    }

    // Adiciona preço histórico e publica evento no RabbitMQ
    @Transactional
    public AssetResponseDTO addPrice(String ticker, PriceRequestDTO requestDTO) {
        String normalizedTicker = ticker.toUpperCase();
        Asset asset = getAssetByTicker(normalizedTicker);

        log.info("Adicionando preço {} para {} em {}",
                requestDTO.getPrice(), normalizedTicker, requestDTO.getPriceDate());

        AssetPrice price = AssetPrice.builder()
                .asset(asset)
                .price(requestDTO.getPrice())
                .priceDate(requestDTO.getPriceDate())
                .build();

        assetPriceRepository.save(price);

        long totalPrices = assetPriceRepository.countByAsset(asset);
        log.info("Preço salvo. Total de preços para {}: {}", normalizedTicker, totalPrices);

        publishPriceUpdatedEvent(asset, requestDTO.getPrice(), requestDTO.getPriceDate());

        return AssetResponseDTO.from(asset, totalPrices);
    }

    // Calcula estatísticas: retorno médio (μ) e volatilidade (σ) - inputs do algoritmo de Markowitz
    @Transactional(readOnly = true)
    public AssetStatsDTO calculateStats(String ticker) {
        Asset asset = getAssetByTicker(ticker.toUpperCase());

        List<AssetPrice> prices = assetPriceRepository.findByAssetOrderByPriceDateAsc(asset);

        if (prices.size() < 2) {
            throw new IllegalArgumentException(
                    "O ativo '" + ticker + "' precisa de pelo menos 2 preços históricos " +
                    "para calcular estatísticas. Preços disponíveis: " + prices.size()
            );
        }

        log.info("Calculando estatísticas para {} com {} preços", ticker, prices.size());

        // Passo 1: Calcular retornos diários rₜ = (Pₜ - Pₜ₋₁) / Pₜ₋₁
        double[] returns = calculateDailyReturns(prices);

        // Passo 2: Calcular retorno médio μ = Σrₜ / n
        double meanReturn = calculateMean(returns);

        // Passo 3: Calcular volatilidade σ = √(Σ(rₜ - μ)² / (n-1))
        double volatility = calculateStandardDeviation(returns, meanReturn);

        // Passo 4: Anualizar métricas (retorno × 252, volatilidade × √252)
        double annualizedReturn     = meanReturn * TRADING_DAYS_PER_YEAR;
        double annualizedVolatility = volatility * Math.sqrt(TRADING_DAYS_PER_YEAR);

        log.info("Estatísticas de {}: retorno_diario={}, volatilidade_diaria={}, retorno_anual={}, volatilidade_anual={}",
                ticker,
                String.format("%.4f", meanReturn),
                String.format("%.4f", volatility),
                String.format("%.4f", annualizedReturn),
                String.format("%.4f", annualizedVolatility));

        return new AssetStatsDTO(
                asset.getTicker(),
                asset.getName(),
                prices.size(),
                meanReturn,
                volatility,
                annualizedVolatility,
                annualizedReturn
        );
    }

    // Calcula retornos diários: rₜ = (Pₜ - Pₜ₋₁) / Pₜ₋₁
    private double[] calculateDailyReturns(List<AssetPrice> prices) {
        double[] returns = new double[prices.size() - 1];

        for (int i = 1; i < prices.size(); i++) {
            BigDecimal currentPrice = prices.get(i).getPrice();
            BigDecimal previousPrice = prices.get(i - 1).getPrice();

            double current  = currentPrice.doubleValue();
            double previous = previousPrice.doubleValue();

            returns[i - 1] = (current - previous) / previous;
        }

        return returns;
    }

    // Calcula média: μ = Σrₜ / n
    private double calculateMean(double[] values) {
        double sum = 0.0;
        for (double value : values) {
            sum += value;
        }
        return sum / values.length;
    }

    // Calcula desvio padrão amostral: σ = √(Σ(rₜ - μ)² / (n-1))
    // Usa (n-1) para correção de Bessel (amostra, não população)
    private double calculateStandardDeviation(double[] returns, double mean) {
        double sumSquaredDeviations = 0.0;

        for (double r : returns) {
            double deviation = r - mean;
            sumSquaredDeviations += deviation * deviation;
        }

        double variance = sumSquaredDeviations / (returns.length - 1);
        return Math.sqrt(variance);
    }

    // Busca ativo por ticker ou lança exceção
    private Asset getAssetByTicker(String ticker) {
        return assetRepository.findByTicker(ticker)
                .orElseThrow(() -> new AssetNotFoundException(
                        "Ativo com ticker '" + ticker + "' não encontrado"));
    }

    // Publica evento no RabbitMQ (fire-and-forget)
    private void publishPriceUpdatedEvent(Asset asset, BigDecimal price,
                                           java.time.LocalDate priceDate) {
        try {
            AssetPriceUpdatedEvent event = new AssetPriceUpdatedEvent(
                    asset.getTicker(),
                    asset.getName(),
                    price,
                    priceDate,
                    LocalDateTime.now()
            );

            rabbitTemplate.convertAndSend(
                    RabbitMQConfig.EXCHANGE_NAME,
                    RabbitMQConfig.ASSET_PRICE_UPDATED_ROUTING_KEY,
                    event
            );

            log.info("✉ Evento 'asset.price.updated' publicado para o ticker: {}",
                    asset.getTicker());

        } catch (Exception e) {
            log.error("Falha ao publicar evento de preço para {}: {}",
                    asset.getTicker(), e.getMessage());
        }
    }
}
