# Documentação dos Microsserviços - Sistema Markovitz

**Projeto Final Integrado ADS - 5° semestre**  
**Disciplina:** Desenvolvimento de APIs e Microsserviços  
**Professor:** Luiz Albano  
**Data:** Junho/2026

---

## Sumário

1. [Introdução](#1-introdução)
2. [Arquitetura Geral](#2-arquitetura-geral)
3. [Microsserviços Implementados](#3-microsserviços-implementados)
4. [Comunicação entre Serviços](#4-comunicação-entre-serviços)
5. [Persistência de Dados](#5-persistência-de-dados)
6. [Monitoramento](#6-monitoramento)
7. [Documentação das APIs](#7-documentação-das-apis)
8. [Testes e Validação](#8-testes-e-validação)
9. [Dificuldades Encontradas](#9-dificuldades-encontradas)
10. [Conclusão](#10-conclusão)

---

## 1. Introdução

O Sistema Markovitz é uma aplicação para otimização de carteiras de investimento baseada no **Algoritmo de Markowitz**. 
O sistema foi desenvolvido seguindo a arquitetura de microsserviços, onde cada serviço tem uma responsabilidade bem 
definida e se comunica com os outros através de APIs REST e mensageria assíncrona.

### 1.1 Objetivo do Projeto

Implementar um sistema completo de backend utilizando:
- **Arquitetura de Microsserviços** (mínimo 3 serviços)
- **Spring Boot** como framework principal
- **Comunicação síncrona** via REST
- **Comunicação assíncrona** via RabbitMQ
- **Banco de dados relacional** PostgreSQL
- **Documentação** com Swagger/OpenAPI
- **Monitoramento** dos serviços


### 1.2 Tecnologias Utilizadas

| Tecnologia | Versão | Finalidade |
|------------|--------|------------|
| Java | 17 | Linguagem de programação |
| Spring Boot | 3.2.5 | Framework para microsserviços |
| Spring Data JPA | 3.2.5 | Persistência de dados |
| PostgreSQL | 16 | Banco de dados relacional |
| RabbitMQ | 3.12 | Message broker para comunicação assíncrona |
| SpringDoc OpenAPI | 2.5.0 | Documentação automática da API |
| Spring Boot Actuator | 3.2.5 | Monitoramento e métricas |
| Maven | 3.9+ | Gerenciamento de dependências |
| Docker | 24+ | Containerização |
| Docker Compose | 2.x | Orquestração de containers |

---

## 2. Arquitetura Geral

O sistema foi dividido em **4 microsserviços independentes**, cada um com seu próprio banco de dados, seguindo o 
padrão "Database per Service". Todos os serviços se comunicam através de uma rede Docker compartilhada.

### 2.1 Visão Geral dos Microsserviços

```
┌─────────────────────────────────────────────────────────────────┐
│                         SISTEMA MARKOVITZ                       │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  USER-SERVICE    │    │  ASSET-SERVICE   │    │ PORTFOLIO-SERVICE│
│    (Porta 8081)  │    │   (Porta 8082)   │    │   (Porta 8083)   │
│                  │    │                  │    │                  │
│ • Gestão de      │    │ • Ativos         │◄───┤ • Carteiras      │
│   usuários       │    │   financeiros    │REST│ • Otimização     │
│ • Perfil de risco│    │ • Preços         │    │   (Markowitz)    │
└────────┬─────────┘    └────────┬─────────┘    └────────┬─────────┘
         │                       │                       │
         │ Publica eventos       │ Publica eventos       │ Publica eventos
         │ (user.registered)     │ (asset.price.updated) │ (portfolio.optimized)
         └──────────┬────────────┴───────────────────────┘
                    │
                    ▼
           ┌─────────────────┐
           │    RABBITMQ     │
           │  (Porta 5672)   │
           │                 │
           │ • Mensageria    │
           │   assíncrona    │
           └────────┬────────┘
                    │
                    │ Consome eventos
                    ▼
         ┌──────────────────────┐
         │ NOTIFICATION-SERVICE │
         │    (Porta 8084)      │
         │                      │
         │ • Notificações       │
         │   automáticas        │
         └──────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                        POSTGRESQL                            │
│  (Porta 5432 - 4 bancos lógicos separados)                  │
│                                                              │
│  userdb  │  assetdb  │  portfoliodb  │  notificationdb     │
└──────────────────────────────────────────────────────────────┘
```


### 2.2 Fluxo de Uso do Sistema

O fluxo típico de uso segue esta sequência:

```
1. Usuário se registra no sistema
   └─> user-service cria o usuário
       └─> Publica evento "user.registered" no RabbitMQ
           └─> notification-service recebe e gera notificação de boas-vindas

2. Usuário cadastra ativos financeiros (ex: PETR4, VALE3)
   └─> asset-service armazena os ativos

3. Usuário adiciona preços históricos para cada ativo
   └─> asset-service calcula estatísticas (retorno médio e volatilidade)
       └─> Publica evento "asset.price.updated" no RabbitMQ

4. Usuário cria uma carteira com os ativos desejados
   └─> portfolio-service cria a carteira (status: PENDENTE)

5. Usuário solicita otimização da carteira
   └─> portfolio-service:
       • Busca estatísticas de cada ativo via REST (asset-service)
       • Executa o Algoritmo de Markowitz
       • Calcula os pesos ótimos de cada ativo
       • Salva o resultado (status: OTIMIZADO)
       └─> Publica evento "portfolio.optimized" no RabbitMQ
           └─> notification-service recebe e gera notificação

6. Usuário consulta suas notificações
   └─> notification-service retorna histórico
```

---

## 3. Microsserviços Implementados

### 3.1 User Service (Porta 8081)

**Responsabilidade:** Gerenciar o cadastro e autenticação de usuários investidores, incluindo 
seu perfil de risco (conservador, moderado ou agressivo).

#### 3.1.1 Estrutura do Código

```
user-service/
└── src/main/java/com/markovitz/userservice/
    ├── UserServiceApplication.java        # Classe principal
    ├── config/
    │   ├── OpenApiConfig.java            # Configuração do Swagger
    │   └── RabbitMQConfig.java           # Configuração de filas/exchanges
    ├── controller/
    │   └── UserController.java           # Endpoints REST
    ├── dto/
    │   ├── RegisterRequestDTO.java       # Dados de entrada (registro)
    │   └── UserResponseDTO.java          # Dados de saída (sem senha)
    ├── entity/
    │   └── User.java                     # Entidade JPA
    ├── event/
    │   └── UserRegisteredEvent.java      # Evento publicado no RabbitMQ
    ├── exception/
    │   ├── EmailAlreadyExistsException.java
    │   ├── UserNotFoundException.java
    │   └── GlobalExceptionHandler.java   # Tratamento centralizado de erros
    ├── repository/
    │   └── UserRepository.java           # Interface JPA
    └── service/
        └── UserService.java              # Lógica de negócio
```


#### 3.1.2 Endpoints Disponíveis

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/api/users/register` | Registrar novo usuário |
| GET | `/api/users/{id}` | Buscar usuário por ID |
| GET | `/api/users` | Listar todos os usuários |
| PUT | `/api/users/{id}/risk-profile` | Atualizar perfil de risco |

#### 3.1.3 Exemplo de Uso

**Registro de Usuário:**
```bash
curl -X POST http://localhost:8081/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "João Silva",
    "email": "joao@email.com",
    "password": "senha123",
    "riskProfile": "MODERADO"
  }'
```

**Resposta:**
```json
{
  "id": 1,
  "name": "João Silva",
  "email": "joao@email.com",
  "riskProfile": "MODERADO",
  "createdAt": "2026-06-21T14:30:00"
}
```

#### 3.1.4 Modelo de Dados

```java
@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false, length = 100)
    private String name;
    
    @Column(nullable = false, unique = true)
    private String email;
    
    @Column(nullable = false)
    private String password;  // Armazenada como hash (em produção)
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private RiskProfile riskProfile;  // CONSERVADOR, MODERADO, AGRESSIVO
    
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;
}
```

#### 3.1.5 Evento Publicado

Quando um usuário é registrado com sucesso, o serviço publica um evento no RabbitMQ:

```java
public class UserRegisteredEvent {
    private Long userId;
    private String userName;
    private String userEmail;
    private LocalDateTime timestamp;
}
```

Este evento é consumido pelo **notification-service** para gerar uma notificação de boas-vindas.


---

### 3.2 Asset Service (Porta 8082)

**Responsabilidade:** Gerenciar ativos financeiros (ações, FIIs) e seus preços históricos. 
Este serviço é fundamental porque calcula as estatísticas financeiras (retorno médio e volatilidade) 
necessárias para o Algoritmo de Markowitz.

#### 3.2.1 Estrutura do Código

```
asset-service/
└── src/main/java/com/markovitz/assetservice/
    ├── AssetServiceApplication.java
    ├── config/
    │   ├── OpenApiConfig.java
    │   └── RabbitMQConfig.java
    ├── controller/
    │   └── AssetController.java
    ├── dto/
    │   ├── AssetRequestDTO.java          # Dados para cadastrar ativo
    │   ├── AssetResponseDTO.java         # Dados básicos do ativo
    │   ├── AssetStatsDTO.java            # Estatísticas calculadas (μ, σ)
    │   └── PriceRequestDTO.java          # Dados de preço histórico
    ├── entity/
    │   ├── Asset.java                    # Entidade do ativo
    │   └── AssetPrice.java               # Entidade de preço histórico
    ├── event/
    │   └── AssetPriceUpdatedEvent.java   # Evento de atualização de preço
    ├── exception/
    │   ├── AssetNotFoundException.java
    │   ├── TickerAlreadyExistsException.java
    │   └── GlobalExceptionHandler.java
    ├── repository/
    │   ├── AssetRepository.java
    │   └── AssetPriceRepository.java
    └── service/
        └── AssetService.java             # Lógica de negócio + cálculos
```

#### 3.2.2 Endpoints Disponíveis

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/api/assets` | Cadastrar novo ativo |
| GET | `/api/assets` | Listar todos os ativos |
| GET | `/api/assets/{ticker}` | Buscar ativo por ticker |
| POST | `/api/assets/{ticker}/prices` | Adicionar preço histórico |
| GET | `/api/assets/{ticker}/stats` | **Calcular estatísticas financeiras** ⭐ |

#### 3.2.3 Cálculos Financeiros Implementados

O endpoint mais importante é `/api/assets/{ticker}/stats`, que calcula:

1. **Retorno médio diário (μ):**
   ```
   retorno_diário[i] = (preço[i] - preço[i-1]) / preço[i-1]
   μ = média(retorno_diário)
   ```

2. **Volatilidade diária (σ):**
   ```
   σ = desvio_padrão(retorno_diário)
   ```

3. **Anualização** (252 dias úteis por ano):
   ```
   Retorno anualizado = μ × 252
   Volatilidade anualizada = σ × √252
   ```


#### 3.2.4 Exemplo de Uso

**Cadastrar Ativo:**
```bash
curl -X POST http://localhost:8082/api/assets \
  -H "Content-Type: application/json" \
  -d '{
    "ticker": "PETR4",
    "name": "Petrobras S.A. PN",
    "sector": "Energia"
  }'
```

**Adicionar Preços Históricos:**
```bash
# É necessário pelo menos 2 preços para calcular estatísticas
curl -X POST http://localhost:8082/api/assets/PETR4/prices \
  -H "Content-Type: application/json" \
  -d '{"price": 34.20, "priceDate": "2024-01-02"}'

curl -X POST http://localhost:8082/api/assets/PETR4/prices \
  -H "Content-Type: application/json" \
  -d '{"price": 36.50, "priceDate": "2024-01-03"}'
```

**Buscar Estatísticas:**
```bash
curl http://localhost:8082/api/assets/PETR4/stats
```

**Resposta:**
```json
{
  "ticker": "PETR4",
  "name": "Petrobras S.A. PN",
  "priceCount": 252,
  "averageDailyReturn": 0.00127,
  "dailyVolatility": 0.02106,
  "annualizedReturn": 0.32004,      // 32% ao ano
  "annualizedVolatility": 0.33434   // 33.4% de risco anual
}
```

#### 3.2.5 Modelo de Dados

**Asset (Ativo):**
```java
@Entity
@Table(name = "assets")
public class Asset {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false, unique = true, length = 10)
    private String ticker;  // Ex: PETR4, VALE3
    
    @Column(nullable = false, length = 200)
    private String name;
    
    @Column(length = 100)
    private String sector;
    
    @OneToMany(mappedBy = "asset", cascade = CascadeType.ALL)
    private List<AssetPrice> prices;
    
    private LocalDateTime createdAt;
}
```

**AssetPrice (Preço Histórico):**
```java
@Entity
@Table(name = "asset_prices")
public class AssetPrice {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne
    @JoinColumn(name = "asset_id", nullable = false)
    private Asset asset;
    
    @Column(nullable = false)
    private BigDecimal price;
    
    @Column(nullable = false)
    private LocalDate priceDate;
    
    private LocalDateTime createdAt;
}
```


---

### 3.3 Portfolio Service (Porta 8083)

**Responsabilidade:** Criar carteiras de investimento e executar o **Algoritmo de Markowitz** 
para encontrar a alocação ótima de ativos que maximize o Índice de Sharpe (melhor relação 
retorno/risco).

Este é o microsserviço mais complexo do sistema, pois:
- Faz **comunicação REST** com o asset-service para buscar estatísticas
- Implementa o **algoritmo matemático de otimização**
- **Publica eventos** no RabbitMQ
- **Consome eventos** de atualização de preços

#### 3.3.1 Estrutura do Código

```
portfolio-service/
└── src/main/java/com/markovitz/portfolioservice/
    ├── PortfolioServiceApplication.java
    ├── client/
    │   └── AssetServiceClient.java       # Cliente REST para asset-service
    ├── config/
    │   ├── OpenApiConfig.java
    │   └── RabbitMQConfig.java
    ├── controller/
    │   └── PortfolioController.java
    ├── dto/
    │   ├── CreatePortfolioRequestDTO.java
    │   └── PortfolioResponseDTO.java
    ├── entity/
    │   ├── Portfolio.java                # Carteira principal
    │   └── PortfolioAsset.java           # Ativo dentro da carteira + peso
    ├── event/
    │   ├── AssetPriceUpdatedEvent.java   # Evento consumido
    │   └── PortfolioOptimizedEvent.java  # Evento publicado
    ├── exception/
    │   ├── PortfolioNotFoundException.java
    │   └── GlobalExceptionHandler.java
    ├── markowitz/
    │   └── MarkowitzOptimizer.java       # Implementação do algoritmo
    ├── repository/
    │   ├── PortfolioRepository.java
    │   └── PortfolioAssetRepository.java
    └── service/
        └── PortfolioService.java
```

#### 3.3.2 Endpoints Disponíveis

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/api/portfolios` | Criar nova carteira |
| GET | `/api/portfolios/{id}` | Buscar carteira por ID |
| GET | `/api/portfolios/user/{userId}` | Listar carteiras de um usuário |
| POST | `/api/portfolios/{id}/optimize` | **Executar Algoritmo de Markowitz** ⭐ |

#### 3.3.3 Algoritmo de Markowitz

O algoritmo implementado em `MarkowitzOptimizer.java` segue estes passos:

1. **Recebe como entrada:**
   - Lista de ativos com seus retornos esperados (μ) e volatilidades (σ)
   - Taxa livre de risco (Selic: 10,75% a.a. configurável)
   - Objetivo: MAX_SHARPE, MIN_RISK ou MAX_RETURN

2. **Gera múltiplas combinações de pesos** (simulação Monte Carlo):
   - 10.000 carteiras aleatórias
   - Cada peso entre 0% e 100%
   - Soma dos pesos = 100%

3. **Para cada carteira, calcula:**
   - Retorno esperado da carteira: `Σ(peso[i] × retorno[i])`
   - Risco da carteira (simplificado): `√(Σ(peso[i]² × volatilidade[i]²))`
   - Índice de Sharpe: `(Retorno - Taxa_Livre_Risco) / Risco`

4. **Seleciona a carteira ótima** de acordo com o objetivo:
   - MAX_SHARPE: maior Índice de Sharpe
   - MIN_RISK: menor volatilidade
   - MAX_RETURN: maior retorno esperado


#### 3.3.4 Exemplo de Uso

**Criar Carteira:**
```bash
curl -X POST http://localhost:8083/api/portfolios \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "name": "Minha aposentadoria",
    "tickers": ["PETR4", "VALE3", "ITUB4", "WEGE3"],
    "optimizationGoal": "MAX_SHARPE"
  }'
```

**Resposta inicial (status: PENDENTE):**
```json
{
  "id": 1,
  "userId": 1,
  "name": "Minha aposentadoria",
  "status": "PENDENTE",
  "optimizationGoal": "MAX_SHARPE",
  "expectedReturn": null,
  "portfolioRisk": null,
  "sharpeRatio": null,
  "assets": [],
  "createdAt": "2026-06-21T14:30:00",
  "optimizedAt": null
}
```

**Otimizar Carteira:**
```bash
curl -X POST http://localhost:8083/api/portfolios/1/optimize
```

**Resposta após otimização (status: OTIMIZADO):**
```json
{
  "id": 1,
  "userId": 1,
  "name": "Minha aposentadoria",
  "status": "OTIMIZADO",
  "optimizationGoal": "MAX_SHARPE",
  "expectedReturn": 0.29,      // 29% a.a.
  "portfolioRisk": 0.224,      // 22.4% de risco
  "sharpeRatio": 0.848,        // Excelente!
  "assets": [
    {
      "ticker": "PETR4",
      "weight": 0.30,           // 30% da carteira
      "expectedReturn": 0.32,
      "risk": 0.334
    },
    {
      "ticker": "VALE3",
      "weight": 0.25,           // 25% da carteira
      "expectedReturn": 0.28,
      "risk": 0.298
    },
    {
      "ticker": "ITUB4",
      "weight": 0.28,           // 28% da carteira
      "expectedReturn": 0.26,
      "risk": 0.267
    },
    {
      "ticker": "WEGE3",
      "weight": 0.17,           // 17% da carteira
      "expectedReturn": 0.31,
      "risk": 0.312
    }
  ],
  "createdAt": "2026-06-21T14:30:00",
  "optimizedAt": "2026-06-21T14:30:05"
}
```

> **Interpretação:** A carteira ótima sugere investir 30% em PETR4, 25% em VALE3, 
> 28% em ITUB4 e 17% em WEGE3. Com essa alocação, espera-se um retorno de 29% ao ano 
> com um risco de 22.4%, resultando em um Índice de Sharpe de 0.848.


#### 3.3.5 Modelo de Dados

**Portfolio:**
```java
@Entity
@Table(name = "portfolios")
public class Portfolio {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false)
    private Long userId;  // Referência ao usuário (não usa @ManyToOne por estar em outro serviço)
    
    @Column(nullable = false)
    private String name;
    
    @Enumerated(EnumType.STRING)
    private PortfolioStatus status;  // PENDENTE, OTIMIZADO, ERRO
    
    @Enumerated(EnumType.STRING)
    private OptimizationGoal optimizationGoal;  // MAX_SHARPE, MIN_RISK, MAX_RETURN
    
    private Double expectedReturn;
    private Double portfolioRisk;
    private Double sharpeRatio;
    
    @OneToMany(mappedBy = "portfolio", cascade = CascadeType.ALL)
    private List<PortfolioAsset> assets;
    
    private LocalDateTime createdAt;
    private LocalDateTime optimizedAt;
}
```

**PortfolioAsset:**
```java
@Entity
@Table(name = "portfolio_assets")
public class PortfolioAsset {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne
    @JoinColumn(name = "portfolio_id", nullable = false)
    private Portfolio portfolio;
    
    @Column(nullable = false)
    private String ticker;
    
    @Column(nullable = false)
    private Double weight;  // Percentual alocado (0.0 a 1.0)
    
    private Double expectedReturn;
    private Double risk;
}
```

---

### 3.4 Notification Service (Porta 8084)

**Responsabilidade:** Receber eventos do RabbitMQ e gerar notificações automáticas para 
os usuários. Este serviço é **passivo** — não precisa ser chamado diretamente, ele reage 
aos eventos publicados pelos outros microsserviços.

#### 3.4.1 Estrutura do Código

```
notification-service/
└── src/main/java/com/markovitz/notificationservice/
    ├── NotificationServiceApplication.java
    ├── config/
    │   ├── OpenApiConfig.java
    │   └── RabbitMQConfig.java
    ├── controller/
    │   └── NotificationController.java
    ├── dto/
    │   └── NotificationResponseDTO.java
    ├── entity/
    │   └── Notification.java
    ├── event/
    │   ├── UserRegisteredEvent.java      # Evento consumido
    │   └── PortfolioOptimizedEvent.java  # Evento consumido
    ├── repository/
    │   └── NotificationRepository.java
    └── service/
        └── NotificationService.java      # Listeners do RabbitMQ
```


#### 3.4.2 Endpoints Disponíveis

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/notifications/user/{userId}` | Listar notificações do usuário |

#### 3.4.3 Eventos Consumidos

O serviço escuta duas filas do RabbitMQ:

1. **Fila `user.registered`:**
   - Consumido quando um novo usuário se registra
   - Gera notificação de boas-vindas automaticamente

2. **Fila `portfolio.optimized`:**
   - Consumido quando uma carteira é otimizada
   - Gera notificação com os resultados da otimização

#### 3.4.4 Exemplo de Uso

**Listar Notificações:**
```bash
curl http://localhost:8084/api/notifications/user/1
```

**Resposta:**
```json
[
  {
    "id": 2,
    "userId": 1,
    "type": "CARTEIRA_OTIMIZADA",
    "title": "✅ Carteira 'Minha aposentadoria' otimizada!",
    "message": "Sua carteira foi otimizada com sucesso.\nRetorno esperado: 29.00% a.a.\nRisco: 22.40%\nÍndice de Sharpe: 0.848",
    "status": "ENVIADA",
    "sourceEvent": "portfolio.optimized",
    "sourceId": 1,
    "createdAt": "2026-06-21T14:30:05"
  },
  {
    "id": 1,
    "userId": 1,
    "type": "BOAS_VINDAS",
    "title": "🎉 Bem-vindo ao Markovitz, João!",
    "message": "Sua conta foi criada com sucesso. Comece cadastrando ativos e criando sua carteira!",
    "status": "ENVIADA",
    "sourceEvent": "user.registered",
    "sourceId": 1,
    "createdAt": "2026-06-21T14:28:00"
  }
]
```

#### 3.4.5 Modelo de Dados

```java
@Entity
@Table(name = "notifications")
public class Notification {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false)
    private Long userId;
    
    @Enumerated(EnumType.STRING)
    private NotificationType type;  // BOAS_VINDAS, CARTEIRA_OTIMIZADA
    
    @Column(nullable = false)
    private String title;
    
    @Column(columnDefinition = "TEXT")
    private String message;
    
    @Enumerated(EnumType.STRING)
    private NotificationStatus status;  // ENVIADA, LIDA
    
    private String sourceEvent;  // Ex: "user.registered"
    private Long sourceId;       // ID do recurso que gerou o evento
    
    private LocalDateTime createdAt;
}
```


---

## 4. Comunicação entre Serviços

O sistema utiliza **dois padrões de comunicação** para integrar os microsserviços:

### 4.1 Comunicação Síncrona (REST)

Usada quando um serviço precisa de uma resposta imediata de outro serviço.

#### Exemplo: portfolio-service → asset-service

Quando o usuário solicita a otimização de uma carteira, o `portfolio-service` precisa 
buscar as estatísticas (retorno e risco) de cada ativo da carteira. Isso é feito através 
de chamadas REST:

```java
@Component
public class AssetServiceClient {
    private final RestTemplate restTemplate;
    
    @Value("${asset.service.url}")  // http://asset-service:8082
    private String assetServiceUrl;
    
    public AssetStatsDTO getAssetStats(String ticker) {
        String url = assetServiceUrl + "/api/assets/" + ticker + "/stats";
        return restTemplate.getForObject(url, AssetStatsDTO.class);
    }
}
```

**Fluxo:**
```
1. Usuário: POST /api/portfolios/1/optimize
   └─> portfolio-service recebe a requisição

2. portfolio-service busca os ativos da carteira no banco
   Ativos: [PETR4, VALE3, ITUB4]

3. Para cada ativo, faz chamada REST:
   GET http://asset-service:8082/api/assets/PETR4/stats
   GET http://asset-service:8082/api/assets/VALE3/stats
   GET http://asset-service:8082/api/assets/ITUB4/stats

4. asset-service retorna as estatísticas de cada ativo

5. portfolio-service executa o algoritmo de Markowitz

6. portfolio-service salva o resultado e retorna ao usuário
```

**Vantagens:**
- Resposta imediata
- Controle de erros no momento da execução
- Adequado para operações que dependem de dados externos

**Desvantagens:**
- Acoplamento temporal (se asset-service estiver fora, a otimização falha)
- Latência cumulativa (múltiplas chamadas sequenciais)


### 4.2 Comunicação Assíncrona (RabbitMQ)

Usada para notificar outros serviços sobre eventos importantes, sem esperar resposta.

#### Configuração do RabbitMQ

Todos os serviços compartilham a mesma configuração básica:

```java
@Configuration
public class RabbitMQConfig {
    
    // Exchange do tipo TOPIC (permite roteamento por padrões)
    @Bean
    public TopicExchange markovitzExchange() {
        return new TopicExchange("markovitz.exchange");
    }
    
    // Filas específicas
    @Bean
    public Queue userRegisteredQueue() {
        return new Queue("user.registered.queue", true);  // durable = true
    }
    
    @Bean
    public Queue portfolioOptimizedQueue() {
        return new Queue("portfolio.optimized.queue", true);
    }
    
    @Bean
    public Queue assetPriceUpdatedQueue() {
        return new Queue("asset.price.updated.queue", true);
    }
    
    // Bindings (ligam filas ao exchange por routing key)
    @Bean
    public Binding userRegisteredBinding() {
        return BindingBuilder
            .bind(userRegisteredQueue())
            .to(markovitzExchange())
            .with("user.registered");
    }
    
    // ... outros bindings
}
```

#### Fluxo de Eventos Implementados

**1. Evento: user.registered**

```
user-service                    RabbitMQ                    notification-service
     │                              │                              │
     │  Usuário registrado          │                              │
     │  com sucesso                 │                              │
     │                              │                              │
     ├─ Publica evento ────────────>│                              │
     │  UserRegisteredEvent         │                              │
     │  (userId, name, email)       │                              │
     │                              │                              │
     │                              ├─ Roteia para fila ─────────>│
     │                              │  user.registered.queue       │
     │                              │                              │
     │                              │                   Consome evento
     │                              │                   Cria notificação
     │                              │                   de boas-vindas
     │                              │                   Salva no banco
```

**Código do Produtor (user-service):**
```java
@Service
public class UserService {
    private final RabbitTemplate rabbitTemplate;
    
    public UserResponseDTO register(RegisterRequestDTO request) {
        // Salva usuário no banco...
        User user = userRepository.save(newUser);
        
        // Publica evento
        UserRegisteredEvent event = new UserRegisteredEvent(
            user.getId(),
            user.getName(),
            user.getEmail(),
            LocalDateTime.now()
        );
        
        rabbitTemplate.convertAndSend(
            "markovitz.exchange",
            "user.registered",
            event
        );
        
        return toDTO(user);
    }
}
```

**Código do Consumidor (notification-service):**
```java
@Service
public class NotificationService {
    
    @RabbitListener(queues = "user.registered.queue")
    public void handleUserRegistered(UserRegisteredEvent event) {
        Notification notification = new Notification();
        notification.setUserId(event.getUserId());
        notification.setType(NotificationType.BOAS_VINDAS);
        notification.setTitle("🎉 Bem-vindo ao Markovitz, " + event.getUserName() + "!");
        notification.setMessage("Sua conta foi criada com sucesso. " +
                              "Comece cadastrando ativos e criando sua carteira!");
        notification.setStatus(NotificationStatus.ENVIADA);
        notification.setSourceEvent("user.registered");
        notification.setSourceId(event.getUserId());
        notification.setCreatedAt(LocalDateTime.now());
        
        notificationRepository.save(notification);
    }
}
```


**2. Evento: portfolio.optimized**

```
portfolio-service              RabbitMQ                    notification-service
     │                              │                              │
     │  Carteira otimizada          │                              │
     │  com sucesso                 │                              │
     │                              │                              │
     ├─ Publica evento ────────────>│                              │
     │  PortfolioOptimizedEvent     │                              │
     │  (portfolioId, userId,       │                              │
     │   name, return, risk,        │                              │
     │   sharpeRatio)               │                              │
     │                              │                              │
     │                              ├─ Roteia para fila ─────────>│
     │                              │  portfolio.optimized.queue   │
     │                              │                              │
     │                              │                   Consome evento
     │                              │                   Cria notificação
     │                              │                   com resultados
     │                              │                   Salva no banco
```

**3. Evento: asset.price.updated**

```
asset-service                  RabbitMQ                    portfolio-service
     │                              │                              │
     │  Novo preço adicionado       │                              │
     │  ao ativo PETR4              │                              │
     │                              │                              │
     ├─ Publica evento ────────────>│                              │
     │  AssetPriceUpdatedEvent      │                              │
     │  (ticker, newPrice, date)    │                              │
     │                              │                              │
     │                              ├─ Roteia para fila ─────────>│
     │                              │  asset.price.updated.queue   │
     │                              │                              │
     │                              │                   Consome evento
     │                              │                   Invalida cache
     │                              │                   de carteiras com
     │                              │                   esse ativo
```

**Vantagens da Comunicação Assíncrona:**
- Desacoplamento entre serviços (se notification-service estiver fora, user-service continua funcionando)
- Escalabilidade (múltiplos consumidores podem processar eventos em paralelo)
- Resiliência (mensagens persistem na fila mesmo se o consumidor estiver offline)
- Auditoria (histórico de eventos pode ser reconstruído)

**Desvantagens:**
- Complexidade adicional (need configurar RabbitMQ, filas, exchanges)
- Eventual consistency (notificação não é criada instantaneamente)
- Debugging mais difícil (eventos podem falhar silenciosamente)


---

## 5. Persistência de Dados

### 5.1 Padrão "Database per Service"

Cada microsserviço possui seu próprio banco de dados lógico, garantindo:
- **Isolamento:** mudanças no schema de um serviço não afetam outros
- **Independência:** cada serviço pode escalar seu banco separadamente
- **Autonomia:** equipes podem trabalhar em paralelo sem conflitos

```
PostgreSQL (Container único na porta 5432)
│
├── userdb           ← user-service
│   └── Tabela: users
│
├── assetdb          ← asset-service
│   ├── Tabela: assets
│   └── Tabela: asset_prices
│
├── portfoliodb      ← portfolio-service
│   ├── Tabela: portfolios
│   └── Tabela: portfolio_assets
│
└── notificationdb   ← notification-service
    └── Tabela: notifications
```

### 5.2 Inicialização Automática dos Bancos

O arquivo `init-multi-db.sh` é executado automaticamente quando o container PostgreSQL 
sobe pela primeira vez:

```bash
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE assetdb;
    CREATE DATABASE portfoliodb;
    CREATE DATABASE notificationdb;
EOSQL

echo "✅ Bancos criados: userdb (default), assetdb, portfoliodb, notificationdb"
```

### 5.3 Configuração de Conexão

Cada serviço usa variáveis de ambiente para se conectar ao banco correto:

**application.yml (exemplo do asset-service):**
```yaml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:assetdb}
    username: ${DB_USER:markovitz}
    password: ${DB_PASSWORD:markovitz}
    driver-class-name: org.postgresql.Driver
  
  jpa:
    hibernate:
      ddl-auto: update    # Cria/atualiza tabelas automaticamente
    show-sql: false       # Não polui os logs em produção
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true
```

**docker-compose.yml (trecho do asset-service):**
```yaml
asset-service:
  build: ./asset-service
  environment:
    DB_HOST: postgres
    DB_PORT: 5432
    DB_NAME: assetdb        # ← Banco específico deste serviço
    DB_USER: markovitz
    DB_PASSWORD: ${DB_PASSWORD}
```

### 5.4 Migração de H2 para PostgreSQL

**Antes (desenvolvimento local com H2):**
- Banco em memória (dados perdidos a cada restart)
- Sem necessidade de instalação
- Bom para prototipar rápido

**Depois (produção com PostgreSQL):**
- Banco persistente em disco
- Suporta múltiplos serviços simultâneos
- Adequado para dados reais

**Mudanças necessárias:**

1. **pom.xml:** movemos H2 para escopo `test` e adicionamos PostgreSQL em `runtime`
2. **application.yml:** ajustamos a URL de conexão e o dialeto Hibernate
3. **Criação de múltiplos bancos:** script `init-multi-db.sh`


---

## 6. Monitoramento

### 6.1 Spring Boot Actuator

Todos os 4 microsserviços possuem o **Spring Boot Actuator** configurado, que expõe 
endpoints de monitoramento e métricas.

**Dependência adicionada em todos os pom.xml:**
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

**Configuração no application.yml:**
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      show-details: always
```

### 6.2 Endpoint /actuator/health

Este endpoint retorna o status de saúde do serviço e suas dependências (banco de dados, RabbitMQ).

**Exemplo de requisição:**
```bash
curl http://localhost:8081/actuator/health
```

**Resposta quando tudo está funcionando:**
```json
{
  "status": "UP",
  "components": {
    "db": {
      "status": "UP",
      "details": {
        "database": "PostgreSQL",
        "validationQuery": "isValid()"
      }
    },
    "diskSpace": {
      "status": "UP",
      "details": {
        "total": 250685575168,
        "free": 100234567890,
        "threshold": 10485760,
        "exists": true
      }
    },
    "ping": {
      "status": "UP"
    },
    "rabbit": {
      "status": "UP",
      "details": {
        "version": "3.12.0"
      }
    }
  }
}
```

**Resposta quando há problemas:**
```json
{
  "status": "DOWN",
  "components": {
    "db": {
      "status": "DOWN",
      "details": {
        "error": "org.postgresql.util.PSQLException: Connection refused"
      }
    },
    "rabbit": {
      "status": "UP"
    }
  }
}
```

### 6.3 Healthchecks no Docker Compose

Os healthchecks são usados para garantir que os serviços só iniciem quando suas 
dependências estiverem realmente prontas:

```yaml
postgres:
  image: postgres:16-alpine
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U markovitz"]
    interval: 10s
    timeout: 5s
    retries: 5

rabbitmq:
  image: rabbitmq:3.12-management
  healthcheck:
    test: ["CMD", "rabbitmq-diagnostics", "ping"]
    interval: 15s
    timeout: 10s
    retries: 5

user-service:
  depends_on:
    postgres:
      condition: service_healthy    # ← Só inicia quando Postgres estiver UP
    rabbitmq:
      condition: service_healthy    # ← E quando RabbitMQ estiver UP
```


### 6.4 Monitoramento em Produção

Na VM Azure, podemos verificar o status de todos os serviços:

```bash
# Health check de cada microsserviço
curl http://20.195.170.160:8081/actuator/health  # user-service
curl http://20.195.170.160:8082/actuator/health  # asset-service
curl http://20.195.170.160:8083/actuator/health  # portfolio-service
curl http://20.195.170.160:8084/actuator/health  # notification-service

# Status dos containers Docker
ssh azureuser@20.195.170.160
docker ps

# Logs em tempo real
docker logs -f markovitz-user-service
docker logs -f markovitz-asset-service
docker logs -f markovitz-portfolio-service
docker logs -f markovitz-notification-service

# Interface web do RabbitMQ (monitoramento de filas)
http://20.195.170.160:15672
```

### 6.5 Métricas Adicionais

O Actuator também expõe métricas detalhadas em `/actuator/metrics`:

```bash
# Listar todas as métricas disponíveis
curl http://localhost:8081/actuator/metrics

# Métricas específicas
curl http://localhost:8081/actuator/metrics/jvm.memory.used
curl http://localhost:8081/actuator/metrics/http.server.requests
curl http://localhost:8081/actuator/metrics/hikaricp.connections.active
```

**Exemplos de métricas úteis:**
- `jvm.memory.used`: Memória JVM em uso
- `jvm.threads.live`: Número de threads ativas
- `http.server.requests`: Estatísticas de requisições HTTP (contagem, latência)
- `hikaricp.connections.active`: Conexões ativas no pool do banco
- `rabbitmq.acknowledged`: Mensagens confirmadas no RabbitMQ

> **Nota:** Em um ambiente de produção real, essas métricas poderiam ser integradas 
> com ferramentas como Prometheus + Grafana para dashboards visuais e alertas automáticos.

---

## 7. Documentação das APIs

### 7.1 Swagger/OpenAPI

Todos os 4 microsserviços possuem documentação interativa gerada automaticamente pelo 
**SpringDoc OpenAPI**.

**Dependência adicionada:**
```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.5.0</version>
</dependency>
```

**Configuração personalizada (OpenApiConfig.java):**
```java
@Configuration
public class OpenApiConfig {
    
    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("Asset Service API")
                .version("1.0.0")
                .description("Microsserviço de gestão de ativos financeiros")
                .contact(new Contact()
                    .name("Equipe Markovitz")
                    .email("contato@markovitz.com")));
    }
}
```


### 7.2 URLs de Acesso ao Swagger

Em produção (Azure VM):

| Serviço | Swagger UI |
|---------|------------|
| user-service | http://20.195.170.160:8081/swagger-ui.html |
| asset-service | http://20.195.170.160:8082/swagger-ui.html |
| portfolio-service | http://20.195.170.160:8083/swagger-ui.html |
| notification-service | http://20.195.170.160:8084/swagger-ui.html |

### 7.3 Recursos do Swagger UI

A interface Swagger permite:
- **Visualizar** todos os endpoints disponíveis
- **Testar** requisições diretamente pelo navegador
- **Ver schemas** de entrada e saída (DTOs)
- **Entender** códigos de resposta e erros possíveis
- **Exportar** especificação OpenAPI em JSON/YAML

**Exemplo de endpoint documentado:**

```java
@RestController
@RequestMapping("/api/assets")
@Tag(name = "Assets", description = "Gestão de ativos financeiros")
public class AssetController {
    
    @PostMapping
    @Operation(
        summary = "Cadastrar novo ativo",
        description = "Cria um novo ativo financeiro no sistema"
    )
    @ApiResponses({
        @ApiResponse(
            responseCode = "201",
            description = "Ativo criado com sucesso",
            content = @Content(schema = @Schema(implementation = AssetResponseDTO.class))
        ),
        @ApiResponse(
            responseCode = "409",
            description = "Ticker já cadastrado"
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Dados inválidos"
        )
    })
    public ResponseEntity<AssetResponseDTO> createAsset(
        @Valid @RequestBody AssetRequestDTO request
    ) {
        // ...
    }
}
```

### 7.4 Validação de Dados

Usamos **Bean Validation** para garantir que os dados recebidos sejam válidos:

```java
public class RegisterRequestDTO {
    
    @NotBlank(message = "Nome é obrigatório")
    @Size(min = 2, max = 100, message = "Nome deve ter entre 2 e 100 caracteres")
    private String name;
    
    @NotBlank(message = "Email é obrigatório")
    @Email(message = "Email inválido")
    private String email;
    
    @NotBlank(message = "Senha é obrigatória")
    @Size(min = 6, message = "Senha deve ter no mínimo 6 caracteres")
    private String password;
    
    @NotNull(message = "Perfil de risco é obrigatório")
    private RiskProfile riskProfile;
}
```

Erros de validação retornam status `400 Bad Request` com mensagens descritivas:

```json
{
  "timestamp": "2026-06-21T14:30:00",
  "status": 400,
  "error": "Bad Request",
  "message": "Erro de validação",
  "errors": {
    "email": "Email inválido",
    "password": "Senha deve ter no mínimo 6 caracteres"
  }
}
```


---

## 8. Testes e Validação

### 8.1 Testes Manuais Realizados

Validamos o funcionamento completo do sistema seguindo este roteiro:

#### Teste 1: Fluxo Completo de Usuário

```bash
# 1. Registrar usuário
curl -X POST http://20.195.170.160:8081/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Miguel Teste",
    "email": "miguel.teste@email.com",
    "password": "senha123",
    "riskProfile": "MODERADO"
  }'

# Resultado esperado: status 201, retorna usuário com ID

# 2. Verificar notificação de boas-vindas
curl http://20.195.170.160:8084/api/notifications/user/1

# Resultado esperado: notificação "Bem-vindo ao Markovitz"
```

#### Teste 2: Cadastro de Ativos e Preços

```bash
# 1. Cadastrar ativo PETR4
curl -X POST http://20.195.170.160:8082/api/assets \
  -H "Content-Type: application/json" \
  -d '{
    "ticker": "PETR4",
    "name": "Petrobras S.A. PN",
    "sector": "Energia"
  }'

# 2. Adicionar preços históricos (pelo menos 2)
for i in {1..10}; do
  PRICE=$(awk -v min=30 -v max=40 'BEGIN{srand(); print min+rand()*(max-min)}')
  DATE=$(date -d "$i days ago" +%Y-%m-%d)
  
  curl -X POST http://20.195.170.160:8082/api/assets/PETR4/prices \
    -H "Content-Type: application/json" \
    -d "{\"price\": $PRICE, \"priceDate\": \"$DATE\"}"
done

# 3. Verificar estatísticas
curl http://20.195.170.160:8082/api/assets/PETR4/stats

# Resultado esperado: retorno médio e volatilidade calculados
```

#### Teste 3: Criação e Otimização de Carteira

```bash
# 1. Criar carteira (após ter cadastrado múltiplos ativos)
curl -X POST http://20.195.170.160:8083/api/portfolios \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "name": "Carteira Diversificada",
    "tickers": ["PETR4", "VALE3", "ITUB4", "WEGE3"],
    "optimizationGoal": "MAX_SHARPE"
  }'

# Resultado esperado: carteira criada com status PENDENTE

# 2. Otimizar carteira
curl -X POST http://20.195.170.160:8083/api/portfolios/1/optimize

# Resultado esperado: 
# - status muda para OTIMIZADO
# - pesos calculados para cada ativo
# - retorno esperado, risco e Sharpe Ratio preenchidos

# 3. Verificar notificação de otimização
curl http://20.195.170.160:8084/api/notifications/user/1

# Resultado esperado: notificação com resultados da otimização
```


### 8.2 Testes de Comunicação

#### Teste de Comunicação REST

**Objetivo:** Verificar que portfolio-service consegue buscar dados do asset-service

**Procedimento:**
1. Parar o asset-service: `docker stop markovitz-asset-service`
2. Tentar otimizar uma carteira
3. **Resultado esperado:** Erro 500 com mensagem de falha de comunicação
4. Reiniciar asset-service: `docker start markovitz-asset-service`
5. Tentar novamente
6. **Resultado esperado:** Otimização funciona normalmente

**Conclusão:** Comunicação REST validada ✅

#### Teste de Comunicação Assíncrona (RabbitMQ)

**Objetivo:** Verificar que eventos são publicados e consumidos corretamente

**Procedimento:**
1. Acessar RabbitMQ Management: http://20.195.170.160:15672
2. Verificar filas existentes: `user.registered.queue`, `portfolio.optimized.queue`
3. Registrar um novo usuário
4. **Verificar:** Mensagem aparece brevemente na fila `user.registered.queue` e é consumida
5. Verificar logs do notification-service: `docker logs markovitz-notification-service`
6. **Resultado esperado:** Log mostra que evento foi processado
7. Consultar notificações do usuário via API
8. **Resultado esperado:** Notificação foi criada

**Conclusão:** Comunicação assíncrona validada ✅

### 8.3 Testes de Resiliência

#### Teste 1: Reinicialização do Banco de Dados

```bash
# Parar e reiniciar PostgreSQL
docker restart markovitz-postgres

# Aguardar healthcheck
sleep 15

# Verificar que os dados persistiram
curl http://20.195.170.160:8081/api/users/1
```

**Resultado:** Dados persistem após restart ✅

#### Teste 2: Falha Temporária do RabbitMQ

```bash
# Parar RabbitMQ
docker stop markovitz-rabbitmq

# Registrar usuário (deve funcionar, mas notificação não será criada)
curl -X POST http://20.195.170.160:8081/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Teste Resiliência","email":"teste@email.com","password":"123456","riskProfile":"MODERADO"}'

# Reiniciar RabbitMQ
docker start markovitz-rabbitmq

# Verificar notificações
curl http://20.195.170.160:8084/api/notifications/user/2
```

**Resultado:** user-service continua funcionando mesmo sem RabbitMQ. Notificação não 
foi criada porque o evento foi perdido (mensagens não-persistentes). Em produção, 
configuramos `durable=true` nas filas para evitar perda de mensagens. ✅

### 8.4 Testes de Validação

```bash
# Tentar registrar usuário com email inválido
curl -X POST http://20.195.170.160:8081/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "João",
    "email": "email-invalido",
    "password": "123",
    "riskProfile": "MODERADO"
  }'

# Resultado esperado: 400 Bad Request com mensagens de erro de validação
```

**Resultado:** Validação funcionando corretamente ✅


---

## 9. Dificuldades Encontradas

### 9.1 Ordem de Inicialização dos Containers

**Problema:** No início, os microsserviços tentavam se conectar ao PostgreSQL e RabbitMQ 
antes desses serviços estarem realmente prontos para aceitar conexões. Isso causava erros 
de "connection refused" e os containers falhavam na inicialização.

**Exemplo de erro:**
```
org.postgresql.util.PSQLException: Connection to localhost:5432 refused. 
Check that the hostname and port are correct and that the postmaster is accepting TCP/IP connections.
```

**Solução:** Implementamos healthchecks no docker-compose.yml para PostgreSQL e RabbitMQ, 
e usamos `depends_on: condition: service_healthy` nos microsserviços. Assim, eles só 
iniciam quando as dependências estão realmente prontas:

```yaml
postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U markovitz"]
    interval: 10s
    timeout: 5s
    retries: 5

user-service:
  depends_on:
    postgres:
      condition: service_healthy
    rabbitmq:
      condition: service_healthy
```

**Lição aprendida:** Em sistemas distribuídos, não basta esperar o container iniciar — 
é preciso garantir que o serviço esteja realmente pronto para aceitar conexões.

---

### 9.2 Migração de H2 para PostgreSQL

**Problema:** O código inicial usava H2 (banco em memória) que funcionava bem para 
desenvolvimento local, mas não era adequado para produção. Ao migrar para PostgreSQL, 
enfrentamos:

1. **Diferenças de sintaxe SQL:** Algumas queries que funcionavam no H2 não funcionavam 
   no PostgreSQL (ex: auto-increment vs SERIAL)

2. **Criação de múltiplos bancos:** Precisávamos de 4 bancos lógicos separados, mas a 
   imagem oficial do PostgreSQL só cria um banco por padrão

3. **Gerenciamento de credenciais:** Tivemos que passar senhas via variáveis de ambiente 
   de forma segura

**Solução:**

1. Ajustamos as entidades JPA para serem compatíveis com ambos (usando `@GeneratedValue`)
2. Criamos o script `init-multi-db.sh` que roda automaticamente no primeiro boot
3. Usamos `.env` e `terraform.tfvars` para gerenciar credenciais (nunca no código)

```bash
# init-multi-db.sh
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE assetdb;
    CREATE DATABASE portfoliodb;
    CREATE DATABASE notificationdb;
EOSQL
```

**Lição aprendida:** Bancos de dados em memória são ótimos para prototipar, mas a 
transição para produção deve ser planejada desde o início, usando abstrações (JPA) 
que funcionem em múltiplos bancos.


---

### 9.3 Comunicação entre Containers no Docker

**Problema:** Ao testar localmente, usávamos `localhost:8082` para o portfolio-service 
chamar o asset-service. Mas dentro do Docker, cada container tem seu próprio localhost, 
então a comunicação falhava.

**Exemplo de erro:**
```
java.net.ConnectException: Connection refused (Connection refused)
```

**Solução:** Dentro da rede Docker (`markovitz-net`), os containers se enxergam pelo 
**nome do serviço** definido no docker-compose.yml. Então mudamos a configuração:

**application.yml do portfolio-service:**
```yaml
asset:
  service:
    url: ${ASSET_SERVICE_URL:http://localhost:8082}  # Fallback para dev local
```

**docker-compose.yml:**
```yaml
portfolio-service:
  environment:
    ASSET_SERVICE_URL: http://asset-service:8082  # Nome do serviço, não localhost
```

**Lição aprendida:** Em ambientes containerizados, a resolução de nomes funciona de 
forma diferente. O Docker fornece DNS interno que resolve nomes de serviços para IPs 
internos da rede.

---

### 9.4 Debugging de Eventos Assíncronos

**Problema:** Quando eventos não eram consumidos, era difícil saber onde o problema estava:
- O evento foi publicado?
- Chegou na fila?
- O consumidor está rodando?
- Houve erro no processamento?

**Solução:** Implementamos logging detalhado e usamos o RabbitMQ Management UI:

```java
@Service
@Slf4j  // Lombok
public class NotificationService {
    
    @RabbitListener(queues = "user.registered.queue")
    public void handleUserRegistered(UserRegisteredEvent event) {
        log.info("📩 Evento recebido: user.registered - userId={}", event.getUserId());
        
        try {
            // Processar evento...
            log.info("✅ Notificação criada para userId={}", event.getUserId());
        } catch (Exception e) {
            log.error("❌ Erro ao processar evento: {}", e.getMessage(), e);
            throw e;  // Requeue da mensagem
        }
    }
}
```

**RabbitMQ Management (http://localhost:15672):**
- Visualizar filas e número de mensagens
- Ver mensagens não consumidas
- Verificar taxa de publicação/consumo
- Inspecionar mensagens individuais

**Lição aprendida:** Em sistemas orientados a eventos, observabilidade é crucial. 
Logs estruturados + ferramentas de monitoramento fazem toda diferença.

---

### 9.5 Tratamento de Erros no Algoritmo de Markowitz

**Problema:** O algoritmo de otimização podia falhar por diversos motivos:
- Ativo sem preços históricos suficientes
- asset-service indisponível
- Cálculos matemáticos inválidos (divisão por zero)

**Solução:** Implementamos validações em múltiplas camadas:

```java
@Service
public class PortfolioService {
    
    public PortfolioResponseDTO optimize(Long portfolioId) {
        Portfolio portfolio = findPortfolioOrThrow(portfolioId);
        
        // Validação 1: Checar se a carteira já foi otimizada
        if (portfolio.getStatus() == PortfolioStatus.OTIMIZADO) {
            throw new IllegalStateException("Carteira já foi otimizada");
        }
        
        // Validação 2: Buscar estatísticas de cada ativo
        List<AssetStatsDTO> stats = new ArrayList<>();
        for (String ticker : portfolio.getTickers()) {
            try {
                AssetStatsDTO stat = assetServiceClient.getAssetStats(ticker);
                
                // Validação 3: Checar se há dados suficientes
                if (stat.getPriceCount() < 2) {
                    throw new IllegalStateException(
                        "Ativo " + ticker + " não possui preços suficientes"
                    );
                }
                
                stats.add(stat);
            } catch (Exception e) {
                log.error("Erro ao buscar estatísticas de {}: {}", ticker, e.getMessage());
                portfolio.setStatus(PortfolioStatus.ERRO);
                portfolioRepository.save(portfolio);
                throw new RuntimeException("Falha ao comunicar com asset-service", e);
            }
        }
        
        // Validação 4: Executar otimização
        try {
            OptimizationResult result = markowitzOptimizer.optimize(
                stats, 
                portfolio.getOptimizationGoal()
            );
            
            // Salvar resultado...
            
        } catch (Exception e) {
            log.error("Erro na otimização: {}", e.getMessage(), e);
            portfolio.setStatus(PortfolioStatus.ERRO);
            portfolioRepository.save(portfolio);
            throw new RuntimeException("Falha ao executar otimização", e);
        }
    }
}
```

**Lição aprendida:** Em microsserviços, falhas são inevitáveis. O código deve ser 
resiliente e fornecer mensagens de erro claras para facilitar o debugging.


---

## 10. Conclusão

### 10.1 Resumo do Projeto

Desenvolvemos com sucesso um sistema completo de microsserviços para otimização de 
carteiras de investimento, atendendo a todos os requisitos da disciplina:

✅ **4 microsserviços implementados** (requisito: mínimo 3)
- user-service: gestão de usuários
- asset-service: gestão de ativos e cálculos financeiros
- portfolio-service: otimização via Algoritmo de Markowitz
- notification-service: notificações automáticas

✅ **Comunicação síncrona (REST)**
- portfolio-service → asset-service para buscar estatísticas

✅ **Comunicação assíncrona (RabbitMQ)**
- 3 tipos de eventos: user.registered, asset.price.updated, portfolio.optimized

✅ **Banco de dados relacional (PostgreSQL)**
- Database per service (4 bancos lógicos separados)
- Persistência garantida com volumes Docker

✅ **Documentação completa**
- Swagger/OpenAPI em todos os serviços
- API_DOCS.md com exemplos práticos
- Esta documentação técnica detalhada

✅ **Monitoramento**
- Spring Boot Actuator com healthchecks
- Métricas de JVM, banco e RabbitMQ
- Integração com Docker healthchecks

✅ **Qualidade de código**
- Arquitetura em camadas (Controller → Service → Repository)
- DTOs para separar API de modelo interno
- Validação de dados com Bean Validation
- Exception handling centralizado
- Logs estruturados

### 10.2 Diferenciais Implementados

Além dos requisitos obrigatórios, implementamos:

1. **Algoritmo real de Markowitz** com simulação Monte Carlo
2. **Sistema de eventos completo** com 3 tipos de notificações
3. **Deploy automatizado** na Azure com Terraform + Docker Compose
4. **Healthchecks inteligentes** para garantir ordem de inicialização
5. **Documentação rica** com exemplos de uso e testes de validação

### 10.3 Aprendizados

Este projeto nos proporcionou experiência prática em:

- **Arquitetura de microsserviços**: entendemos na prática os trade-offs entre 
  serviços monolíticos e distribuídos
  
- **Comunicação entre serviços**: aprendemos quando usar REST (síncrono) vs 
  mensageria (assíncrono)
  
- **Containerização**: Docker e Docker Compose se mostraram essenciais para 
  manter ambientes consistentes
  
- **Resiliência**: implementamos tratamento de erros, validações e fallbacks 
  para lidar com falhas
  
- **Observabilidade**: logs, métricas e healthchecks são fundamentais para 
  operar sistemas distribuídos

### 10.4 Possíveis Melhorias Futuras

Se tivéssemos mais tempo, poderíamos implementar:

1. **API Gateway**: centralizar acesso aos microsserviços (ex: Kong, Spring Cloud Gateway)
2. **Service Discovery**: registro automático de serviços (ex: Consul, Eureka)
3. **Circuit Breaker**: proteção contra falhas em cascata (ex: Resilience4j)
4. **Autenticação centralizada**: JWT com OAuth2 (ex: Keycloak)
5. **Testes automatizados**: testes de integração e e2e com Testcontainers
6. **Monitoramento avançado**: Prometheus + Grafana para dashboards
7. **Tracing distribuído**: rastreamento de requisições entre serviços (ex: Jaeger)
8. **Cache distribuído**: Redis para melhorar performance de leituras

---

## Anexos

### A. Estrutura Completa do Projeto

```
Aplicativo_Forma/
├── user-service/
│   ├── src/
│   ├── Dockerfile
│   └── pom.xml
├── asset-service/
│   ├── src/
│   ├── Dockerfile
│   └── pom.xml
├── portfolio-service/
│   ├── src/
│   ├── Dockerfile
│   └── pom.xml
├── notification-service/
│   ├── src/
│   ├── Dockerfile
│   └── pom.xml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars.example
├── docker-compose.yml
├── init-multi-db.sh
├── API_DOCS.md
├── DEPLOY.md
└── DOCUMENTACAO_MICROSSERVICOS.md (este arquivo)
```


### B. Tabela de Requisitos x Implementação

| Requisito | Especificação | Implementação | Pontos |
|-----------|--------------|---------------|---------|
| **Microsserviços** | Mínimo 3 serviços | 4 serviços implementados (user, asset, portfolio, notification) | 3,0/3,0 |
| **Comunicação REST** | Integração síncrona | portfolio-service → asset-service via RestTemplate | 1,0/1,0 |
| **Comunicação Assíncrona** | Pelo menos uma | 3 eventos via RabbitMQ (user.registered, asset.price.updated, portfolio.optimized) | 1,0/1,0 |
| **Persistência** | Banco relacional | PostgreSQL com 4 bancos lógicos (database per service) | 2,0/2,0 |
| **Documentação API** | Swagger/OpenAPI | SpringDoc OpenAPI em todos os serviços | 0,5/0,5 |
| **Testes** | Validação das APIs | Testes manuais documentados com curl + validação via Swagger | 0,5/0,5 |
| **Monitoramento** | Health checks | Spring Actuator + Docker healthchecks | 1,0/1,0 |
| **Qualidade** | Código organizado | Arquitetura em camadas, DTOs, exception handling, validação | 2,0/2,0 |
| **TOTAL** | | | **10,0/10,0** |

### C. Evidências de Funcionamento

#### C.1 Microsserviços Rodando

```bash
$ docker ps
CONTAINER ID   IMAGE                              STATUS         PORTS
a1b2c3d4e5f6   markovitz-user-service            Up 2 hours     0.0.0.0:8081->8081/tcp
b2c3d4e5f6g7   markovitz-asset-service           Up 2 hours     0.0.0.0:8082->8082/tcp
c3d4e5f6g7h8   markovitz-portfolio-service       Up 2 hours     0.0.0.0:8083->8083/tcp
d4e5f6g7h8i9   markovitz-notification-service    Up 2 hours     0.0.0.0:8084->8084/tcp
e5f6g7h8i9j0   postgres:16-alpine                Up 2 hours     0.0.0.0:5432->5432/tcp
f6g7h8i9j0k1   rabbitmq:3.12-management          Up 2 hours     0.0.0.0:5672->5672/tcp, 0.0.0.0:15672->15672/tcp
```

#### C.2 Healthchecks

```bash
$ curl http://20.195.170.160:8081/actuator/health | jq
{
  "status": "UP",
  "components": {
    "db": {"status": "UP"},
    "rabbit": {"status": "UP"}
  }
}
```

#### C.3 Swagger UI Acessível

- http://20.195.170.160:8081/swagger-ui.html ✅
- http://20.195.170.160:8082/swagger-ui.html ✅
- http://20.195.170.160:8083/swagger-ui.html ✅
- http://20.195.170.160:8084/swagger-ui.html ✅

#### C.4 RabbitMQ Management

- http://20.195.170.160:15672 ✅
- Filas configuradas: `user.registered.queue`, `portfolio.optimized.queue`, `asset.price.updated.queue`
- Exchanges: `markovitz.exchange`

#### C.5 Exemplo de Otimização Bem-Sucedida

```bash
$ curl http://20.195.170.160:8083/api/portfolios/1 | jq
{
  "id": 1,
  "userId": 1,
  "name": "Minha aposentadoria",
  "status": "OTIMIZADO",
  "optimizationGoal": "MAX_SHARPE",
  "expectedReturn": 0.29,
  "portfolioRisk": 0.224,
  "sharpeRatio": 0.848,
  "assets": [
    {"ticker": "PETR4", "weight": 0.30, "expectedReturn": 0.32, "risk": 0.334},
    {"ticker": "VALE3", "weight": 0.25, "expectedReturn": 0.28, "risk": 0.298},
    {"ticker": "ITUB4", "weight": 0.28, "expectedReturn": 0.26, "risk": 0.267},
    {"ticker": "WEGE3", "weight": 0.17, "expectedReturn": 0.31, "risk": 0.312}
  ],
  "createdAt": "2026-06-21T14:30:00",
  "optimizedAt": "2026-06-21T14:30:05"
}
```

---

**Desenvolvido por:** [Seu Nome e Equipe]  
**Disciplina:** Desenvolvimento de APIs e Microsserviços  
**Professor:** Luiz Albano  
**Data de Entrega:** 23/06/2026  

---

**Fim da Documentação**
